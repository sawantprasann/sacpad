module SocialConnections
  # Writes the YouTube channels or X accounts the user ticked.
  class SaveAccounts
    def self.call(user:, pending:, page_ids:)
      wanted = Array(page_ids).map(&:to_s)
      selected = pending.items.select { |item| item["access_token"].present? && wanted.include?(item["id"].to_s) }
      return [] if selected.empty?

      SocialMedia::SocialPage.transaction do
        records = selected.map { |item| upsert(user, pending, item) }
        pending.destroy!
        records
      end
    end

    def self.upsert(user, pending, item)
      record = SocialMedia::SocialPage.with_discarded.find_or_initialize_by(
        provider: pending.provider, external_id: item.fetch("id").to_s
      )
      record.undiscard if record.persisted? && record.discarded?
      record.owner ||= user
      record.update!(
        name: item["name"],
        username: item["username"].presence,
        url: item["link"].presence,
        profile_image_url: https_url(item.dig("picture", "data", "url")),
        access_token: item["access_token"],
        refresh_token: item["refresh_token"].presence,
        expires_at: expires_at(item["expires_at"]),
        provider_uid: pending.provider_uid,
        parent_external_id: nil,
        status: :active,
        last_error: nil,
        last_error_at: nil
      )
      record
    end

    def self.https_url(value)
      value if value.to_s.start_with?("https://")
    end

    def self.expires_at(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
