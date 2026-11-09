module SocialConnections
  # Writes the Facebook Pages the user ticked, plus any linked Instagram
  # professional account they also ticked. Instagram uses that Page's token.
  class SaveFacebookPages
    def self.call(user:, pending:, page_ids:, instagram_ids: [])
      wanted = Array(page_ids).map(&:to_s)
      ig_wanted = Array(instagram_ids).map(&:to_s)
      selected = pending.items.select { |page| page["access_token"].present? && keep?(page, wanted, ig_wanted) }
      return [] if selected.empty?

      SocialMedia::SocialPage.transaction do
        records = selected.map { |page| upsert(user, page, pending.provider_uid) }
        selected.each do |page|
          ig = page["instagram_business_account"]
          next unless ig && ig_wanted.include?(ig["id"].to_s)

          records << upsert_instagram(user, page, ig, pending.provider_uid)
        end
        drop_unticked_instagram(selected, ig_wanted)
        pending.destroy!
        records
      end
    end

    def self.keep?(page, wanted, ig_wanted)
      return true if wanted.include?(page["id"].to_s)

      ig_id = page.dig("instagram_business_account", "id").to_s
      ig_id.present? && ig_wanted.include?(ig_id)
    end

    def self.drop_unticked_instagram(pages, ig_wanted)
      pages.each do |page|
        linked = SocialMedia::SocialPage.instagram.connection_active.where(parent_external_id: page["id"].to_s)
        ig_id = page.dig("instagram_business_account", "id").to_s
        linked = linked.where.not(external_id: ig_id) if ig_wanted.include?(ig_id)
        linked.find_each(&:disconnect!)
      end
    end

    def self.upsert(user, page, provider_uid)
      record = SocialMedia::SocialPage.with_discarded.find_or_initialize_by(
        provider: :facebook, external_id: page.fetch("id").to_s
      )
      record.undiscard if record.persisted? && record.discarded?
      record.owner ||= user
      record.update!(
        name: page["name"],
        username: page["username"].presence,
        url: page["link"].presence,
        profile_image_url: page.dig("picture", "data", "url").presence,
        access_token: page["access_token"],
        provider_uid: provider_uid,
        parent_external_id: nil,
        expires_at: nil,
        status: :active,
        last_error: nil,
        last_error_at: nil
      )
      record
    end

    def self.upsert_instagram(user, page, ig, provider_uid)
      record = SocialMedia::SocialPage.with_discarded.find_or_initialize_by(
        provider: :instagram, external_id: ig.fetch("id").to_s
      )
      record.undiscard if record.persisted? && record.discarded?
      username = ig["username"].presence
      record.owner ||= user
      record.update!(
        name: ig["name"].presence || username || page["name"],
        username: username,
        url: (username ? "https://www.instagram.com/#{username}/" : nil),
        profile_image_url: https_url(ig["profile_picture_url"]),
        access_token: page["access_token"],
        provider_uid: provider_uid,
        parent_external_id: page.fetch("id").to_s,
        expires_at: nil,
        status: :active,
        last_error: nil,
        last_error_at: nil
      )
      record
    end

    def self.https_url(value)
      value if value.to_s.start_with?("https://")
    end
  end
end
