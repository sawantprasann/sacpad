module SocialConnections
  # Lists the YouTube channels owned by the Google account that just signed in.
  class YoutubeApi
    class Error < StandardError; end

    URL = "https://www.googleapis.com/youtube/v3/channels"

    def self.channels(access_token)
      response = Faraday.get(URL) do |request|
        request.params["part"] = "snippet"
        request.params["mine"] = "true"
        request.params["maxResults"] = "50"
        request.headers["Authorization"] = "Bearer #{access_token}"
      end
      raise Error, "YouTube request failed (#{response.status})" unless response.success?

      JSON.parse(response.body).fetch("items", [])
    rescue Faraday::Error, JSON::ParserError
      raise Error, "YouTube request failed"
    end
  end
end
