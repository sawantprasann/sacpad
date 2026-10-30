# Paste into a production Rails console, or load this file:
#
#   load Rails.root.join("script/devnagri_place_names.rb")
#   District.where("name ILIKE ?", "%Pune%").pluck(:id, :name)
#   DevnagriPlaceNames.run(district_id: 123, dry_run: true)
#   DevnagriPlaceNames.run(district_id: 123, dry_run: false)
#
# One district. Reads the English name of that district, its talukas, the
# villages in those talukas, and the police stations those villages use.
# Stores the Marathi spelling on native_name.
#
#   2|Pune ### 4|Haveli ### 12|Wagholi
#   => 2|पुणे ### 4|हवेली ### 12|वाघोली
#
# Each request is one record type, so an id is never applied to the wrong table.
# rewrite: false fills only a blank native_name.

require "json"
require "net/http"

module DevnagriPlaceNames
  URL = URI("https://devnagri.com/api/translate/")
  SEPARATOR = " ### "

  def self.run(district_id:, dry_run: true, batch_size: 25, dest_lang: nil, rewrite: true)
    district = District.find(district_id)
    dest_lang = dest_lang.presence || district.resolved_native_locale.presence || "mr"
    talukas = district.talukas
    villages = Village.where(taluka_id: talukas.select(:id))
    police_stations = PoliceStation.where(id: villages.where.not(police_station_id: nil).select(:police_station_id))
    puts "district #{district.id} #{district.name}: talukas=#{talukas.count} villages=#{villages.count} police_stations=#{police_stations.count} dest_lang=#{dest_lang}"

    saved = skipped = 0
    each_batch(district, talukas, villages, police_stations, batch_size, dest_lang, rewrite) do |batch, lang|
      wrote, missed = flush(batch, lang, dry_run)
      saved += wrote
      skipped += missed
    end

    puts "done saved=#{saved} skipped=#{skipped} dry_run=#{dry_run}"
  end

  def self.each_batch(district, talukas, villages, police_stations, batch_size, dest_lang, rewrite)
    batch = []
    current_class = nil

    each_record(district, talukas, villages, police_stations) do |record|
      next if record.name.blank?
      next if !rewrite && record.native_name.present?

      if current_class && (record.class != current_class || batch.size >= batch_size)
        yield batch, dest_lang
        batch = []
      end

      current_class = record.class
      batch << record
    end

    yield batch, dest_lang if batch.any?
  end

  def self.each_record(district, talukas, villages, police_stations)
    yield district
    talukas.find_each { |record| yield record }
    villages.find_each { |record| yield record }
    police_stations.find_each { |record| yield record }
  end

  def self.flush(batch, dest_lang, dry_run)
    sentence = batch.map { |record| "#{record.id}|#{record.name.to_s.squish}" }.join(SEPARATOR)
    translated = translate(sentence, dest_lang)
    by_id = {}
    translated.to_s.split("###").each do |piece|
      id, name = piece.strip.split("|", 2)
      by_id[id.to_i] = name.to_s.squish if id.to_s.match?(/\A\d+\z/) && name.present?
    end

    saved = skipped = 0
    batch.each do |record|
      native_name = by_id[record.id]
      if native_name.blank?
        skipped += 1
        puts "SKIP #{record.class.name} #{record.id} #{record.name}"
        next
      end

      puts "#{record.class.name} #{record.id} #{record.name} => #{native_name}"
      record.update!(native_name: native_name) unless dry_run
      saved += 1
    end
    [ saved, skipped ]
  end

  def self.translate(sentence, dest_lang)
    6.times do |attempt|
      http = Net::HTTP.new(URL.host, URL.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 90
      request = Net::HTTP::Post.new(URL)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = { sentence: sentence, src_lang: "en", dest_lang: dest_lang }.to_json
      response = http.request(request)
      body = JSON.parse(response.body)
      return body["translated_text"] if body["translated_text"].present?

      wait = body["error"].to_s[/after (\d+) seconds/i, 1]
      raise "Devnagri #{response.code}: #{response.body}" if wait.blank? || attempt == 5

      sleep wait.to_i + 1
    end
  end
end
