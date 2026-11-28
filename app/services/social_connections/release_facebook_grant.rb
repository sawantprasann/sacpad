module SocialConnections
  # Facebook's "Opt in to current Pages only" dialog remembers every Page
  # granted to this login. Dropping the Page permissions makes the next
  # connect start with those Pages unchecked. A failure here must not block
  # the local disconnect.
  class ReleaseFacebookGrant
    PERMISSIONS = %w[
      pages_show_list
      pages_manage_posts
      pages_read_engagement
      pages_read_user_content
      instagram_basic
      instagram_content_publish
      instagram_manage_contents
    ].freeze

    def self.call(page)
      return unless page.facebook?
      return if page.provider_uid.blank?
      return unless MetaApi.configured?

      token = "#{MetaCredentials.app_id}|#{MetaCredentials.app_secret}"
      PERMISSIONS.each do |permission|
        MetaApi::Graph.delete("/#{page.provider_uid}/permissions/#{permission}", access_token: token)
      rescue MetaApi::Graph::Error
        next
      end
    end
  end
end
