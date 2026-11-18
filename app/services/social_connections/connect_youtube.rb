module SocialConnections
  # Lists the channels on the Google account and holds them until the person
  # ticks which ones to keep. One user token covers every channel on it.
  class ConnectYoutube
    def self.call(user:, auth:)
      token = auth.credentials&.token
      return if token.blank?

      channels = YoutubeApi.channels(token).filter_map { |channel| item(channel, auth) }
      return if channels.empty?

      user.pending_connections.create!(
        provider: :youtube,
        provider_uid: auth.uid,
        items: channels
      )
    end

    def self.item(channel, auth)
      snippet = channel["snippet"] || {}
      id = channel["id"].to_s
      return if id.blank?

      handle = snippet["customUrl"].to_s.delete_prefix("@").presence
      thumb = snippet.dig("thumbnails", "high", "url") ||
        snippet.dig("thumbnails", "medium", "url") ||
        snippet.dig("thumbnails", "default", "url")
      {
        "id" => id,
        "name" => snippet["title"],
        "username" => handle,
        "link" => handle ? "https://www.youtube.com/@#{handle}" : "https://www.youtube.com/channel/#{id}",
        "picture" => thumb.present? ? { "data" => { "url" => thumb } } : nil
      }.merge(token_fields(auth))
    end

    def self.token_fields(auth)
      stamp = auth.credentials&.expires_at
      {
        "access_token" => auth.credentials.token,
        "refresh_token" => auth.credentials.refresh_token,
        "expires_at" => stamp.present? ? Time.zone.at(stamp.to_i).iso8601 : nil
      }
    end
  end
end
