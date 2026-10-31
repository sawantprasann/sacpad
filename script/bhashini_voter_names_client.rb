#!/usr/bin/env ruby
# Runs on your machine, not on the server.
#
#   SACPAD_URL=https://app.example.com SACPAD_ROLL_TOKEN=secret DISTRICT_ID=12 ruby script/bhashini_voter_names_client.rb
#
# For each village it loads id, first_name, middle_name, and last_name, translates
# in batches of 200 (Bhashini rejects a longer list), then posts the Marathi
# parts back. The server updates those voters by id.

require "json"
require "net/http"
require "uri"

BASE = ENV.fetch("SACPAD_URL").chomp("/")
TOKEN = ENV.fetch("SACPAD_ROLL_TOKEN")
DISTRICT_ID = ENV.fetch("DISTRICT_ID")
BATCH_SIZE = 200
URL = URI("https://anuvaad.bhashini.gov.in/v1/pipeline")
SERVICE_ID = "bhashini/sarvam/nmt"

def sacpad(method, path, body = nil)
  uri = URI("#{BASE}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 15
  http.read_timeout = 120
  request = method.new(uri)
  request["Authorization"] = "Bearer #{TOKEN}"
  request["Accept"] = "application/json"
  if body
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(body)
  end
  response = http.request(request)
  parsed = JSON.parse(response.body) rescue {}
  raise "Sacpad #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  parsed
end

def translate(names)
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
    request.body = JSON.generate(body)
    response = http.request(request)
    parsed = JSON.parse(response.body)
    output = parsed.dig("pipelineResponse", 0, "output")
    return output if output.is_a?(Array) && output.size == names.size

    wait = parsed["error"].to_s[/after (\d+) seconds/i, 1] || (response.code == "429" ? "20" : nil)
    raise "Bhashini #{response.code}: #{response.body}" if wait.nil? || attempt == 5

    sleep wait.to_i + 1
  end
end

def english_name(voter)
  [ voter["first_name"], voter["middle_name"], voter["last_name"] ].compact.map(&:strip).reject(&:empty?).join(" ")
end

def native_attrs(voter, translated)
  return if translated.to_s.strip.empty?

  parts = [
    [ "native_first_name", voter["first_name"] ],
    [ "native_middle_name", voter["middle_name"] ],
    [ "native_last_name", voter["last_name"] ]
  ].filter_map do |key, value|
    text = value.to_s.strip
    [ key, text ] unless text.empty?
  end
  words = translated.strip.split
  return if words.size != parts.sum { |_, text| text.split.size }

  index = 0
  attrs = { "id" => voter["id"] }
  parts.each do |key, text|
    count = text.split.size
    attrs[key] = words[index, count].join(" ")
    index += count
  end
  attrs
end

def translate_village(voters)
  translated_rows = []
  voters.each_slice(BATCH_SIZE) do |batch|
    names = batch.map { |voter| english_name(voter) }
    output = translate(names)
    batch.each_with_index do |voter, index|
      row = output[index] || {}
      target = row["target"].to_s.strip
      source = row["source"].to_s.strip
      target = nil unless source.empty? || source == names[index]
      attrs = native_attrs(voter, target)
      if attrs.nil?
        puts "SKIP #{voter["id"]} #{names[index]} => #{row["target"].inspect}"
        next
      end

      puts "#{voter["id"]} #{names[index]} => #{attrs.except("id").values.join(" ")}"
      translated_rows << attrs
    end
  end
  translated_rows
end

villages = sacpad(Net::HTTP::Get, "/api/districts/#{DISTRICT_ID}/villages")["villages"]
puts "district #{DISTRICT_ID}: #{villages.size} villages"

villages.each do |village|
  query = ENV["MISSING"] == "1" ? "?missing=1" : ""
  payload = sacpad(Net::HTTP::Get, "/api/villages/#{village["id"]}/voter_names#{query}")
  voters = payload["voters"] || []
  puts "village #{village["id"]} #{village["name"]}: #{voters.size} voters"
  next if voters.empty?

  rows = translate_village(voters)
  next if rows.empty?

  result = sacpad(Net::HTTP::Post, "/api/villages/#{village["id"]}/voter_names", { "voters" => rows })
  puts "saved village #{village["id"]} updated=#{result["updated"]} missing=#{Array(result["missing"]).size}"
end
