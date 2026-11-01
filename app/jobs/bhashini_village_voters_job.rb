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
  RETRY_STATUSES = %w[429 502 503 504].freeze

  def perform(village_id)
    village = Village.find(village_id)
    # A rerun should not send names already saved yesterday or today.
    window = self.class.recent_window
    skipped_recent = village.voters.where(updated_at: window).count
    voters = village.voters.where.not(updated_at: window).to_a.select { |voter| english_name(voter).present? }
    saved = 0
    skipped = 0

    batch_count = (voters.size.to_f / BATCH_SIZE).ceil
    log "start village=#{village.id} #{village.name} voters=#{voters.size} skipped_recent=#{skipped_recent} batches=#{batch_count}"

    voters.each_slice(BATCH_SIZE).with_index do |batch, batch_index|
      batch_no = batch_index + 1
      names = batch.map { |voter| english_name(voter) }
      log "sending village=#{village.id} batch=#{batch_no}/#{batch_count} names=#{names.size}"
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      translated = self.class.translate(names)
      seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)
      log "received village=#{village.id} batch=#{batch_no}/#{batch_count} rows=#{translated.size} seconds=#{seconds}"

      batch_saved = 0
      batch_skipped = 0
      batch.each_with_index do |voter, index|
        row = translated[index] || {}
        target = row["target"].to_s.squish
        source = row["source"].to_s.squish
        target = nil unless source.blank? || source == names[index]
        attrs = native_attrs(voter, target)
        if attrs.nil?
          skipped += 1
          batch_skipped += 1
          next
        end

        PaperTrail.request(enabled: false) { voter.update!(attrs) }
        saved += 1
        batch_saved += 1
      end
      log "saved village=#{village.id} batch=#{batch_no}/#{batch_count} saved=#{batch_saved} skipped=#{batch_skipped} total_saved=#{saved} total_skipped=#{skipped}"
    end

    log "done village=#{village.id} #{village.name} saved=#{saved} skipped=#{skipped} skipped_recent=#{skipped_recent}"
  rescue StandardError => error
    log "failed village=#{village_id} #{error.class}: #{error.message}", level: :error
    raise
  end

  # Yesterday and today on the India calendar. updated_at is stored in UTC.
  def self.recent_window
    zone = ActiveSupport::TimeZone["Asia/Kolkata"]
    start_of_today = zone.now.beginning_of_day
    (start_of_today - 1.day)...(start_of_today + 1.day)
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
      log "http attempt=#{attempt + 1}/6 names=#{names.size}"
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = post(body)
      seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)
      parsed = json_body(response)
      output = parsed&.dig("pipelineResponse", 0, "output")
      log "http status=#{response.code} json=#{parsed.present?} rows=#{output.is_a?(Array) ? output.size : 0} seconds=#{seconds}"
      return output if output.is_a?(Array) && output.size == names.size

      wait = parsed&.dig("error").to_s[/after (\d+) seconds/i, 1]
      wait ||= "20" if parsed.nil? || RETRY_STATUSES.include?(response.code)
      if wait.blank? || attempt == 5
        raise "Bhashini #{response.code}: #{response.body.to_s[0, 180]}"
      end

      log "retry in #{wait.to_i + 1}s attempt=#{attempt + 1}/6 status=#{response.code}", level: :warn
      pause(wait.to_i + 1)
    end
  end

  def self.log(message, level: :info)
    line = "[BhashiniVillageVotersJob] #{message}"
    Rails.logger.public_send(level, line)
    $stdout.puts(line)
    $stdout.flush
  end

  def self.post(body)
    http = Net::HTTP.new(URL.host, URL.port)
    http.use_ssl = true
    http.open_timeout = 15
    http.read_timeout = 180
    request = Net::HTTP::Post.new(URL)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request.body = body.to_json
    http.request(request)
  end

  # A 504 from the gateway is an HTML page, not JSON. Treat that as a failed
  # attempt so the batch is sent again instead of killing the village job.
  def self.json_body(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    nil
  end

  def self.pause(seconds)
    sleep seconds
  end

  def log(message, level: :info)
    self.class.log(message, level: level)
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
