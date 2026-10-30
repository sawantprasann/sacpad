# Paste into a production Rails console, or load this file:
#
#   load Rails.root.join("script/devnagri_native_names.rb")
#   Village.where("name ILIKE ?", "%Wagholi%").pluck(:id, :name)
#   DevnagriNativeNames.run(village_id: 123, dry_run: true)
#   DevnagriNativeNames.run(village_id: 123, dry_run: false)
#
# One request sends many voters. The API leaves digits, "|" and "###" as they are:
#
#   101|Swati Atul Borade ### 102|Ravi Kale
#   => 101|स्वाती अतुल बोराडे ### 102|रवी काले
#
# Those pieces are stored on native_first_name, native_middle_name, native_last_name.
# A voter is skipped when the Marathi word count does not match the English name.
# rewrite: false fills only voters with a blank native_first_name.

require "json"
require "net/http"

module DevnagriNativeNames
  URL = URI("https://devnagri.com/api/translate/")
  SEPARATOR = " ### "

  def self.run(village_id:, dry_run: true, limit: nil, batch_size: 25, dest_lang: nil, rewrite: true)
    village = Village.find(village_id)
    dest_lang = dest_lang.presence || village.resolved_native_locale.presence || "mr"
    scope = village.voters
    puts "village #{village.id} #{village.name}: #{scope.count} voters, dest_lang=#{dest_lang}"

    batch = []
    seen = saved = skipped = 0

    scope.find_each do |voter|
      break if limit && seen >= limit
      next if english_name(voter).blank?
      next if !rewrite && voter.native_first_name.present?

      batch << voter
      seen += 1
      next if batch.size < batch_size || (limit && seen < limit && batch.size < batch_size)

      wrote, missed = flush(batch, dest_lang, dry_run)
      saved += wrote
      skipped += missed
      batch = []
    end

    if batch.any?
      wrote, missed = flush(batch, dest_lang, dry_run)
      saved += wrote
      skipped += missed
    end

    puts "done saved=#{saved} skipped=#{skipped} dry_run=#{dry_run}"
  end

  def self.flush(batch, dest_lang, dry_run)
    sentence = batch.map { |voter| "#{voter.id}|#{english_name(voter)}" }.join(SEPARATOR)
    translated = translate(sentence, dest_lang)
    by_id = {}
    translated.to_s.split("###").each do |piece|
      id, name = piece.strip.split("|", 2)
      by_id[id.to_i] = name.to_s.squish if id.to_s.match?(/\A\d+\z/) && name.present?
    end

    saved = skipped = 0
    batch.each do |voter|
      attrs = native_attrs(voter, by_id[voter.id])
      if attrs.nil?
        skipped += 1
        puts "SKIP #{voter.id} #{english_name(voter)} => #{by_id[voter.id].inspect}"
        next
      end

      puts "#{voter.id} #{english_name(voter)} => #{attrs.values.join(' ')}"
      voter.update!(attrs) unless dry_run
      saved += 1
    end
    [ saved, skipped ]
  end

  def self.native_attrs(voter, translated)
    return if translated.blank?

    parts = [
      [ :native_first_name, voter.first_name ],
      [ :native_middle_name, voter.middle_name ],
      [ :native_last_name, voter.last_name ]
    ].filter_map do |attr, value|
      text = value.to_s.squish
      [ attr, text ] if text.present?
    end
    words = translated.split
    return if words.size != parts.sum { |_, text| text.split.size }

    index = 0
    parts.to_h do |attr, text|
      count = text.split.size
      value = words[index, count].join(" ")
      index += count
      [ attr, value ]
    end
  end

  def self.english_name(voter)
    [ voter.first_name, voter.middle_name, voter.last_name ].compact_blank.map { |part| part.to_s.squish }.join(" ")
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
