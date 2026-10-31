# Paste into a production Rails console, or load this file:
#
#   load Rails.root.join("script/bhashini_village_names.rb")
#   District.where("name ILIKE ?", "%Pune%").pluck(:id, :name)
#   BhashiniVillageNames.run(district_id: 123, dry_run: true)
#   BhashiniVillageNames.run(district_id: 123, dry_run: false)
#
# One district. Sends that district, its talukas, the villages in those talukas,
# and the police stations those villages use. Stores the Marathi spelling on native_name.
#
#   { "source": "Washi" }  =>  { "source": "Washi", "target": "वाशी" }
#
# rewrite: false fills only a blank native_name.

require "json"
require "net/http"

module BhashiniVillageNames
  URL = URI("https://anuvaad.bhashini.gov.in/v1/pipeline")
  SERVICE_ID = "bhashini/sarvam/nmt"

  def self.run(district_id:, dry_run: true, batch_size: 100, dest_lang: nil, rewrite: true)
    district = District.find(district_id)
    dest_lang = dest_lang.presence || district.resolved_native_locale.presence || "mr"
    talukas = district.talukas
    villages = Village.where(taluka_id: talukas.select(:id))
    police_stations = PoliceStation.where(id: villages.where.not(police_station_id: nil).select(:police_station_id))
    puts "district #{district.id} #{district.name}: talukas=#{talukas.count} villages=#{villages.count} police_stations=#{police_stations.count} dest_lang=#{dest_lang}"

    saved = skipped = 0
    each_batch(district, talukas, villages, police_stations, batch_size, rewrite) do |batch|
      wrote, missed = flush(batch, dest_lang, dry_run)
      saved += wrote
      skipped += missed
    end

    puts "done saved=#{saved} skipped=#{skipped} dry_run=#{dry_run}"
  end

  def self.each_batch(district, talukas, villages, police_stations, batch_size, rewrite)
    batch = []
    current_class = nil

    each_record(district, talukas, villages, police_stations) do |record|
      next if record.name.blank?
      next if !rewrite && record.native_name.present?

      if current_class && (record.class != current_class || batch.size >= batch_size)
        yield batch
        batch = []
      end

      current_class = record.class
      batch << record
    end

    yield batch if batch.any?
  end

  def self.each_record(district, talukas, villages, police_stations)
    yield district
    talukas.find_each { |record| yield record }
    villages.find_each { |record| yield record }
    police_stations.find_each { |record| yield record }
  end

  def self.flush(batch, dest_lang, dry_run)
    names = batch.map { |record| record.name.to_s.squish }
    translated = translate(names, dest_lang) || []

    saved = skipped = 0
    batch.each_with_index do |record, index|
      row = translated[index] || {}
      target = row["target"].to_s.squish
      source = row["source"].to_s.squish
      target = nil unless source.blank? || source == names[index]
      if target.blank?
        skipped += 1
        puts "SKIP #{record.class.name} #{record.id} #{names[index]}"
        next
      end

      puts "#{record.class.name} #{record.id} #{names[index]} => #{target}"
      record.update!(native_name: target) unless dry_run
      saved += 1
    end
    [ saved, skipped ]
  end

  def self.translate(names, dest_lang)
    body = {
      pipelineTasks: [
        {
          taskType: "translation",
          config: {
            language: {
              sourceLanguage: "en",
              targetLanguage: dest_lang,
              sourceScriptCode: "Latn",
              targetScriptCode: "Deva"
            },
            postProcessors: [ "glossary" ],
            serviceId: SERVICE_ID
          }
        }
      ],
      inputData: {
        input: names.map { |name| { source: name } },
        audio: [ { audioContent: nil } ]
      }
    }

    6.times do |attempt|
      http = Net::HTTP.new(URL.host, URL.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 120
      request = Net::HTTP::Post.new(URL)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = body.to_json
      response = http.request(request)
      parsed = JSON.parse(response.body)
      output = parsed.dig("pipelineResponse", 0, "output")
      return output if output.is_a?(Array) && output.size == names.size

      wait = parsed["error"].to_s[/after (\d+) seconds/i, 1] || (response.code == "429" ? "20" : nil)
      raise "Bhashini #{response.code}: #{response.body}" if wait.blank? || attempt == 5

      sleep wait.to_i + 1
    end
  end
end
