# Paste into a production Rails console, or load this file:
#
#   load Rails.root.join("script/bhashini_voter_names.rb")
#   Village.where("name ILIKE ?", "%VAKADI%").pluck(:id, :name)
#   BhashiniVoterNames.run(village_id: 1111, dry_run: true)
#   BhashiniVoterNames.run(village_id: 1111, dry_run: false)
#
# One village. Each request holds at most 200 names, so a larger village is
# split into several requests. Four requests run at the same time.
# district_id still works: it runs this same path once per village in that district.
# Stores the Marathi parts on native_first_name, native_middle_name, and
# native_last_name.
#
#   { "source": "Swati Atul Borade" }
#   => { "source": "Swati Atul Borade", "target": "स्वाती अतुल बोराडे" }
#
# A voter is skipped when the Marathi word count does not match the English name.
# rewrite: false fills only voters with a blank native_first_name.

require "json"
require "net/http"
require "thread"

module BhashiniVoterNames
  URL = URI("https://anuvaad.bhashini.gov.in/v1/pipeline")
  SERVICE_ID = "bhashini/sarvam/nmt"
  BATCH_SIZE = 200

  def self.run(village_id: nil, district_id: nil, dry_run: true, threads: 4, dest_lang: nil, rewrite: true)
    if village_id
      run_village(Village.find(village_id), dry_run:, threads:, dest_lang:, rewrite:)
    elsif district_id
      district = District.find(district_id)
      villages = Village.where(taluka_id: district.talukas.select(:id))
      puts "district #{district.id} #{district.name}: villages=#{villages.count}"
      villages.find_each do |village|
        run_village(village, dry_run:, threads:, dest_lang:, rewrite:)
      end
    else
      raise ArgumentError, "Pass village_id or district_id"
    end
  end

  def self.run_village(village, dry_run:, threads:, dest_lang:, rewrite:)
    dest_lang = dest_lang.presence || village.resolved_native_locale.presence || "mr"
    voters = Voter.where(village_id: village.id)
    groups = village_groups(voters, rewrite).flat_map { |group| group.each_slice(BATCH_SIZE).to_a }
    puts "village #{village.id} #{village.name}: requests=#{groups.size} voters=#{groups.sum(&:size)} threads=#{threads} dest_lang=#{dest_lang}"

    saved, skipped = parallel(groups, dest_lang, dry_run, threads)
    puts "done village=#{village.id} #{village.name} saved=#{saved} skipped=#{skipped} dry_run=#{dry_run}"
    [ saved, skipped ]
  end

  def self.village_groups(voters, rewrite)
    grouped = {}
    voters.includes(:village).find_each do |voter|
      name = english_name(voter)
      next if name.blank?
      next if !rewrite && voter.native_first_name.present?

      (grouped[voter.village_id] ||= []) << {
        id: voter.id,
        village_id: voter.village_id,
        village_name: voter.village&.name,
        first_name: voter.first_name,
        middle_name: voter.middle_name,
        last_name: voter.last_name,
        name: name
      }
    end
    grouped.values
  end

  def self.parallel(groups, dest_lang, dry_run, threads)
    return [ 0, 0 ] if groups.empty?

    work = Queue.new
    groups.each { |group| work << group }
    thread_count = [ threads.to_i, 1 ].max
    thread_count.times { work << :done }
    results = Queue.new

    workers = Array.new(thread_count) do
      Thread.new do
        loop do
          group = work.pop
          break if group == :done

          names = group.map { |voter| voter[:name] }
          translated = translate(names, dest_lang)
          results << [ group, translated ]
        rescue StandardError => error
          results << [ group, error ]
        end
      end
    end

    saved = skipped = 0
    groups.size.times do
      group, translated = results.pop
      wrote, missed = apply(group, translated, dry_run)
      saved += wrote
      skipped += missed
    end
    workers.each(&:join)
    [ saved, skipped ]
  end

  def self.apply(group, translated, dry_run)
    village_name = group.first[:village_name]
    if translated.is_a?(StandardError)
      puts "ERROR village #{group.first[:village_id]} #{village_name} voters=#{group.size}: #{translated.message}"
      return [ 0, group.size ]
    end

    puts "village #{group.first[:village_id]} #{village_name}: #{group.size} voters"
    saved = skipped = 0
    group.each_with_index do |voter, index|
      row = translated[index] || {}
      target = row["target"].to_s.squish
      source = row["source"].to_s.squish
      target = nil unless source.blank? || source == voter[:name]
      attrs = native_attrs(voter, target)
      if attrs.nil?
        skipped += 1
        puts "SKIP Voter #{voter[:id]} #{voter[:name]} => #{row["target"].inspect}"
        next
      end

      puts "Voter #{voter[:id]} #{voter[:name]} => #{attrs.values.join(" ")}"
      Voter.find(voter[:id]).update!(attrs) unless dry_run
      saved += 1
    end
    [ saved, skipped ]
  end

  def self.native_attrs(voter, translated)
    return if translated.blank?

    parts = [
      [ :native_first_name, voter[:first_name] ],
      [ :native_middle_name, voter[:middle_name] ],
      [ :native_last_name, voter[:last_name] ]
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
      http.read_timeout = 180
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
