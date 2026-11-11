module SocialConnections
  # Exchanges the short-lived login for a long-lived token, lists the Pages the
  # person granted, and holds that list until they tick which ones to keep.
  class ConnectFacebook
    FIELDS = "id,name,access_token,category,username,link,picture{url},instagram_business_account{id,username}"

    def self.call(user:, auth:)
      token = MetaApi::Graph.long_lived_user_token(auth.credentials.token)
      pages = MetaApi::Graph.get_all("/me/accounts",
        access_token: token, limit: 100, fields: FIELDS)
      pages = granted_pages(token) if pages.empty?
      return if pages.empty?

      attach_instagram(pages)

      user.pending_connections.create!(
        provider: :facebook,
        provider_uid: auth.uid,
        items: pages
      )
    end

    # "Current Pages only" stores the ticked Page ids on the token, not in the list.
    def self.granted_pages(token)
      MetaApi::Graph.granted_page_ids(token).filter_map { |id| fetch_page(token, id) }
    end

    def self.fetch_page(token, id)
      MetaApi::Graph.get("/#{id}", access_token: token, fields: FIELDS)
    rescue MetaApi::Graph::Error
      fallback_page(token, id)
    end

    # The Page token can read the linked professional account. A missing
    # permission leaves the id and username already on the Page.
    def self.attach_instagram(pages)
      return unless MetaApi.configured?

      pages.each do |page|
        ig = page["instagram_business_account"]
        next if ig.blank? || ig["id"].blank? || page["access_token"].blank?

        begin
          profile = MetaApi::Graph.get("/#{ig["id"]}",
            access_token: page["access_token"],
            fields: "id,username,name,profile_picture_url")
          ig.merge!(profile.slice("id", "username", "name", "profile_picture_url"))
        rescue MetaApi::Graph::Error
          next
        end
      end
    end

    def self.fallback_page(token, id)
      MetaApi::Graph.get("/#{id}", access_token: token, fields: "id,name,access_token,category,username,link,picture{url}")
    rescue MetaApi::Graph::Error
      nil
    end
  end
end
