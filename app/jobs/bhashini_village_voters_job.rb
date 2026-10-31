require "json"
require "net/http"

# Translates one village's voter names and stores the Marathi parts.
# Queue one job per village so a dropped console session does not stop the work,
# and finished jobs show which villages are done.
class BhashiniVillageVotersJob < ApplicationJob
  queue_as :default

  URL = URI("https://anuvaad.bhashini.gov.in/v1/pipeline")
  SERVICE_ID = "bhashini/sarvam/nmt"
  BATCH_SIZE = 200

  def perform(village_id)
    village = Village.find(village_id)
    voters = village.voters.to_a.select { |voter| english_name(voter).present? }
    saved = 0
    skipped = 0

    Rails.logger.info("[BhashiniVillageVotersJob] start village=#{village.id} #{village.name} voters=#{voters.size}")

    voters.each_slice(BATCH_SIZE) do |batch|
      names = batch.map { |voter| english_name(voter) }
      translated = self.class.translate(names)
      batch.each_with_index do |voter, index|
        row = translated[index] || {}
        target = row["target"].to_s.squish
        source = row["source"].to_s.squish
        target = nil unless source.blank? || source == names[index]
        attrs = native_attrs(voter, target)
        if attrs.nil?
          skipped += 1
          next
        end

        PaperTrail.request(enabled: false) { voter.update!(attrs) }
        saved += 1
      end
    end

    Rails.logger.info("[BhashiniVillageVotersJob] done village=#{village.id} #{village.name} saved=#{saved} skipped=#{skipped}")
  end

  def self.translate(names)
    body = {
      pipelineTasks: [
        {
          taskType: "translation",
          config: {
            language: {
              sourceLanguage: "en",
              targetLanguage: "mr",
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

  def english_name(voter)
    [ voter.first_name, voter.middle_name, voter.last_name ].compact_blank.map { |part| part.to_s.squish }.join(" ")
  end

  def native_attrs(voter, translated)
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
end
