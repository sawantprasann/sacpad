module SocialConnections
  # Changes the words on every Facebook Page that received this post.
  # Instagram does not allow a published caption to change. Photos and video stay as they are.
  class UpdatePost
    Result = Struct.new(:saved, :failed, keyword_init: true)

    def self.call(post:, body:)
      text = body.to_s.strip
      targets = post.targets.includes(:social_page).to_a
      raise PublishFacebookText::NeedText if text.blank? && !visual?(post, targets)

      failed = []
      targets.each do |target|
        next unless remote?(target)

        if target.social_page.instagram?
          failed << target
          target.update!(error_message: I18n.t("social.instagram_caption_locked"))
          next
        end

        sync_remote(target, text)
        target.update!(error_message: nil) if target.error_message.present?
      rescue MetaApi::Graph::Error => e
        failed << target
        target.update!(error_message: e.message.to_s.truncate(300))
      end

      remote_count = targets.count { |target| remote?(target) }
      if remote_count.positive? && failed.size == remote_count
        return Result.new(saved: false, failed: failed)
      end

      post.update!(body: text.presence)
      Result.new(saved: true, failed: failed)
    end

    def self.visual?(post, targets)
      post.images.attached? || post.video.attached? || targets.any? { |target| target.provider_state.to_h["picture_url"].present? }
    end

    def self.remote?(target)
      page = target.social_page
      target.external_post_id.present? && page.connection_active? && page.access_token.present? && page.provider_uid != "sample"
    end

    def self.sync_remote(target, text)
      MetaApi::Graph.post("/#{target.external_post_id}", access_token: target.social_page.access_token, message: text)
    end

    private_class_method :visual?, :remote?, :sync_remote
  end
end
