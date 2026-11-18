module SocialConnections
  # Holds the X account from the login until the person confirms it.
  # The profile comes back with the token, so this does not call X again.
  class ConnectTwitter
    def self.call(user:, auth:)
      token = auth.credentials&.token
      id = auth.uid.to_s
      return if token.blank? || id.blank?

      username = auth.info&.nickname.to_s.delete_prefix("@").presence
      image = auth.info&.image
      user.pending_connections.create!(
        provider: :twitter,
        provider_uid: id,
        items: [ {
          "id" => id,
          "name" => auth.info&.name.presence || username,
          "username" => username,
          "link" => (username ? "https://x.com/#{username}" : nil),
          "picture" => image.present? ? { "data" => { "url" => image } } : nil,
          "access_token" => token,
          "refresh_token" => auth.credentials.refresh_token,
          "expires_at" => expires_at(auth)
        } ]
      )
    end

    def self.expires_at(auth)
      stamp = auth.credentials&.expires_at
      Time.zone.at(stamp.to_i).iso8601 if stamp.present?
    end
  end
end
