module SocialConnections
  # Sends one text post to the Facebook Pages the author ticked.
  # A failure on one Page does not cancel the others.
  class PublishFacebookText
    class NeedText < StandardError; end
    class NothingSelected < StandardError; end

    def self.ready?(page)
      page.facebook? && page.connection_active? && page.access_token.present? && page.provider_uid != "sample"
    end

    class MixedMedia < StandardError; end

    def self.call(user:, body:, page_ids:, images: [], video: nil)
      text = body.to_s.strip
      photos = Array(images).reject(&:blank?).first(4)
      clip = video.presence
      raise NeedText if text.blank? && photos.empty? && clip.blank?
      raise MixedMedia if photos.any? && clip.present?

      pages = SocialMedia::SocialPage.facebook.connection_active.where(id: Array(page_ids)).select { |page| ready?(page) }
      raise NothingSelected if pages.empty?

      post = SocialMedia::BulkPost.new(
        owner: user,
        body: text.presence,
        status: :queued,
        target_scope: :explicit
      )
      post.images.attach(photos) if photos.any?
      post.video.attach(clip) if clip.present?
      post.save!
      pages.each { |page| publish_to(post, page) }
      finish(post)
      post
    end

    def self.publish_to(post, page)
      target = post.targets.create!(
        social_page: page,
        organization: page.organization,
        status: :processing,
        idempotency_key: "publish:#{post.id}:#{page.id}"
      )
      result = deliver(page, post)
      post_id = (result["post_id"].presence || result["id"]).to_s
      target.update!(
        status: :published,
        external_post_id: post_id.presence,
        permalink: permalink_for(post_id),
        published_at: Time.current,
        provider_state: { "source" => "sacpad" },
        error_message: nil
      )
    rescue MetaApi::Graph::Error => e
      target&.update!(
        status: :failed,
        error_message: e.message.to_s.truncate(300),
        attempts: target.attempts.to_i + 1
      )
      if e.token_error?
        page.update!(status: :needs_reauth, last_error: e.message.to_s.truncate(200), last_error_at: Time.current)
      end
    end

    def self.deliver(page, post)
      token = page.access_token
      if post.video.attached?
        upload_media(page, post.video, description: post.body.to_s)
      elsif post.images.attached?
        photos = post.images.to_a
        if photos.one?
          upload_media(page, photos.first, caption: post.body.to_s, published: true, edge: "photos")
        else
          ids = photos.map { |image| upload_media(page, image, published: false, edge: "photos").fetch("id") }
          fields = { access_token: token }
          fields[:message] = post.body if post.body.present?
          ids.each_with_index { |id, index| fields["attached_media[#{index}]"] = { media_fbid: id }.to_json }
          MetaApi::Graph.post("/#{page.external_id}/feed", fields)
        end
      else
        MetaApi::Graph.post("/#{page.external_id}/feed", access_token: token, message: post.body)
      end
    end

    def self.upload_media(page, attachment, edge: "videos", **fields)
      attachment.blob.open do |io|
        MetaApi::Graph.upload("/#{page.external_id}/#{edge}",
          fields.merge(
            access_token: page.access_token,
            source: io,
            filename: attachment.filename.to_s,
            content_type: attachment.content_type
          ))
      end
    end

    def self.finish(post)
      statuses = post.targets.reload.map(&:status)
      status = if statuses.all?("published")
        :completed
      elsif statuses.all?("failed")
        :failed
      else
        :partially_failed
      end
      post.update!(status: status)
    end

    def self.permalink_for(post_id)
      page_id, story_id = post_id.to_s.split("_", 2)
      return if page_id.blank? || story_id.blank?

      "https://www.facebook.com/#{page_id}/posts/#{story_id}"
    end

    private_class_method :publish_to, :deliver, :upload_media, :finish, :permalink_for
  end
end
