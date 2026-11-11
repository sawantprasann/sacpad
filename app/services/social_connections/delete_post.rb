module SocialConnections
  # Removes the post from every Page and Instagram account that received it.
  # A Page that refuses the delete keeps its copy, and the post stays in the app.
  class DeletePost
    Result = Struct.new(:failed, keyword_init: true)

    def self.call(post:, actor:)
      failed = []
      post.targets.includes(:social_page).to_a.each do |target|
        if remote?(target)
          MetaApi::Graph.delete("/#{target.external_post_id}", access_token: target.social_page.access_token)
        end
        target.destroy!
      rescue MetaApi::Graph::Error => e
        failed << target
        target.update!(error_message: e.message.to_s.truncate(300))
      end
      post.discard_by(actor) if post.targets.reload.none?
      Result.new(failed: failed)
    end

    def self.remote?(target)
      page = target.social_page
      target.external_post_id.present? && page.connection_active? && page.access_token.present? && page.provider_uid != "sample"
    end

    private_class_method :remote?
  end
end
