module Eci
  # Open Election Commission gateway calls for the assembly list.
  # District assemblies: GET /common/acs/:districtCd
  class Client
    class Error < StandardError; end

    BASE_URL = "https://gateway-voters.eci.gov.in/api/v1".freeze

    def initialize(connection: nil)
      @connection = connection || build_connection
    end

    def districts(state_cd)
      body = get("common/districts/#{state_cd}")
      raise Error, "No district list was returned for this state." unless body.is_a?(Array)

      body
    end

    def assemblies(district_cd)
      body = get("common/acs/#{district_cd}")
      raise Error, "No assembly list was returned for this district." unless body.is_a?(Array)

      body
    end

    private

    def get(path, params = nil, headers = nil)
      response = @connection.get(path) do |request|
        request.params.update(params) if params
        headers&.each { |key, value| request.headers[key] = value }
      end
      unless response.success?
        raise Error, "Election Commission request failed (HTTP #{response.status})."
      end

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "Election Commission returned a response that could not be read."
    rescue Faraday::Error => e
      raise Error, "Could not reach the Election Commission (#{e.message})."
    end

    def build_connection
      Faraday.new(url: BASE_URL) do |connection|
        connection.options.timeout = 20
        connection.options.open_timeout = 8
        connection.headers["Accept"] = "application/json"
        connection.headers["Origin"] = "https://voters.eci.gov.in"
        connection.headers["Referer"] = "https://voters.eci.gov.in/"
        connection.headers["User-Agent"] = "sacpad"
      end
    end
  end
end
