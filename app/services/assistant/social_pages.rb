module Assistant
  class SocialPages
    def self.tool_name = "social_pages"
    def self.place_mode = :none
    def self.available_to?(user) = user.role.can_access?("social_media")

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Social Media menu. Connected pages and recent posts. No place is needed. Never returns passwords or access tokens.",
          parameters: { type: "object", properties: {} }
        }
      }
    end

    def self.sanitize(_arguments) = {}

    def self.call(user:, place: nil, arguments: nil, client: nil)
      pages = Pundit.policy_scope(user, SocialMedia::SocialPage).order(:name)
      posts = SocialMedia::BulkPost.kept.order(created_at: :desc).limit(5)
      lines = [ I18n.t("assistant.answers.social.pages", count: pages.count) ]
      pages.limit(15).each do |page|
        lines << "#{page.name.presence || page.username.presence || page.external_id} · #{page.provider} · #{page.page_type} · #{page.status}"
      end
      lines << I18n.t("assistant.answers.social.posts", count: SocialMedia::BulkPost.kept.count)
      posts.each do |post|
        lines << "#{post.title.presence || post.body.to_s.squish.truncate(80)} · #{post.status}"
      end
      Answers.report(lines, link_path: Rails.application.routes.url_helpers.social_connections_path, link_label: I18n.t("assistant.open_list"))
    end
  end
end
