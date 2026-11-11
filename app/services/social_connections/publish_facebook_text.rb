module SocialConnections
  # Sends one post to the Facebook Pages and Instagram accounts the author ticked.
  # A failure on one account does not cancel the others.
  class PublishFacebookText
    class NeedText < StandardError; end
    class NeedMedia < StandardError; end
    class NothingSelected < StandardError; end
    class MixedMedia < StandardError; end

    def self.ready?(page)
      return false unless page.connection_active? && page.access_token.present? && page.provider_uid != "sample"

      page.facebook? || page.instagram?
    end

    def self.call(user:, body:, page_ids:, images: [], video: nil)
      text = body.to_s.strip
      photos = Array(images).reject(&:blank?).first(4)
      clip = video.presence
      raise NeedText if text.blank? && photos.empty? && clip.blank?
      raise MixedMedia if photos.any? && clip.present?

      pages = SocialMedia::SocialPage.connection_active.where(id: Array(page_ids), provider: %i[facebook instagram]).select { |page| ready?(page) }
      raise NothingSelected if pages.empty?
      raise NeedMedia if pages.all?(&:instagram?) && photos.empty? && clip.blank?

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
        permalink: result["permalink"].presence || permalink_for(post_id),
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
      return deliver_instagram(page, post) if page.instagram?

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

    def self.deliver_instagram(page, post)
      token = page.access_token
      container_id = if post.video.attached?
        publish_instagram_video(page, post)
      elsif post.images.attached?
        publish_instagram_photos(page, post)
      else
        raise MetaApi::Graph::Error.new("Instagram needs a photo or a video.")
      end
      published = MetaApi::Graph.post("/#{page.external_id}/media_publish", access_token: token, creation_id: container_id)
      media_id = published["id"].to_s
      permalink = MetaApi::Graph.get("/#{media_id}", access_token: token, fields: "permalink")["permalink"]
      published.merge("permalink" => permalink)
    rescue MetaApi::Graph::Error
      raise if published.nil?

      published
    end

    def self.publish_instagram_photos(page, post)
      photos = post.images.to_a
      if photos.one?
        container = create_image_container(page, photos.first, caption: post.body)
        container.fetch("id")
      else
        child_ids = photos.map { |image| create_image_container(page, image, carousel: true).fetch("id") }
        fields = { access_token: page.access_token, media_type: "CAROUSEL", children: child_ids.join(",") }
        fields[:caption] = post.body if post.body.present?
        carousel = MetaApi::Graph.post("/#{page.external_id}/media", fields)
        wait_until_finished(page, carousel.fetch("id"))
        carousel.fetch("id")
      end
    end

    def self.create_image_container(page, attachment, caption: nil, carousel: false)
      fields = { access_token: page.access_token, image_url: hosted_image_url(page, attachment) }
      fields[:caption] = caption if caption.present? && !carousel
      fields[:is_carousel_item] = true if carousel
      container = MetaApi::Graph.post("/#{page.external_id}/media", fields)
      wait_until_finished(page, container.fetch("id"))
      container
    end

    # Instagram fetches the photo from a public URL. A local file is placed on
    # the linked Facebook Page first, unpublished, and that address is reused.
    def self.hosted_image_url(page, attachment)
      parent_id = page.parent_external_id
      raise MetaApi::Graph::Error.new("Connect the Facebook Page linked to this Instagram account.") if parent_id.blank?

      uploaded = attachment.blob.open do |io|
        MetaApi::Graph.upload("/#{parent_id}/photos",
          access_token: page.access_token,
          published: false,
          source: io,
          filename: attachment.filename.to_s,
          content_type: attachment.content_type)
      end
      photo = MetaApi::Graph.get("/#{uploaded.fetch("id")}", access_token: page.access_token, fields: "images")
      url = Array(photo["images"]).max_by { |image| image["width"].to_i }&.dig("source")
      raise MetaApi::Graph::Error.new("Facebook did not return a photo address for Instagram.") if url.blank?

      url
    end

    def self.publish_instagram_video(page, post)
      fields = { access_token: page.access_token, media_type: "REELS", upload_type: "resumable" }
      fields[:caption] = post.body if post.body.present?
      container = MetaApi::Graph.post("/#{page.external_id}/media", fields)
      url = container["uri"].presence || "https://rupload.facebook.com/ig-api-upload/#{MetaApi::Graph::VERSION}/#{container.fetch("id")}"
      post.video.blob.open do |io|
        MetaApi::Graph.upload_binary(url, io, token: page.access_token, file_size: post.video.byte_size)
      end
      wait_until_finished(page, container.fetch("id"))
      container.fetch("id")
    end

    def self.wait_until_finished(page, container_id)
      15.times do
        status = MetaApi::Graph.get("/#{container_id}", access_token: page.access_token, fields: "status_code")
        code = status["status_code"].to_s
        return if %w[FINISHED PUBLISHED].include?(code)
        if %w[ERROR EXPIRED].include?(code)
          raise MetaApi::Graph::Error.new(status["status"].presence || "Instagram could not prepare the media.")
        end

        sleep 2
      end
      raise MetaApi::Graph::Error.new("Instagram is still preparing the media. Try again in a minute.")
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

    private_class_method :publish_to, :deliver, :deliver_instagram, :publish_instagram_photos,
      :create_image_container, :hosted_image_url, :publish_instagram_video, :wait_until_finished,
      :upload_media, :finish, :permalink_for
  end
end
