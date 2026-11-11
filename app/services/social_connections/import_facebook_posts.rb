module SocialConnections
  # Reads the Page's own Facebook posts and stores the latest batch with
  # like, comment, and share counts. Comment text is not downloaded.
  class ImportFacebookPosts
    LIMIT = 50
    FRESH_FOR = 15.minutes
    FIELDS = "id,message,story,created_time,permalink_url,full_picture,shares,comments.summary(true),reactions.summary(true)"
    BASIC_FIELDS = "id,message,story,created_time,permalink_url,full_picture,shares"

    def self.due?(page)
      return false unless importable?(page)
      return false unless MetaApi.configured?

      snapshot = page.metric_snapshots.find_by(captured_on: Date.current)
      snapshot.nil? || snapshot.updated_at < FRESH_FOR.ago
    end

    def self.importable?(page)
      page.facebook? && page.connection_active? && page.access_token.present? && page.provider_uid != "sample"
    end

    def self.call(page:)
      return [] unless importable?(page)

      body = fetch(page)
      posts = Array(body["data"]).first(LIMIT)
      total = number(body.dig("summary", "total_count")) || posts.size

      SocialMedia::BulkPost.transaction do
        posts.each { |post| upsert(page, post) }
        write_posts_count(page, total)
      end
      page.update!(last_error: nil, last_error_at: nil) if page.last_error.present?
      posts
    end

    def self.fetch(page)
      request(page, FIELDS)
    rescue MetaApi::Graph::Error => e
      raise if e.token_error?

      request(page, BASIC_FIELDS)
    end

    def self.request(page, fields)
      MetaApi::Graph.get("/#{page.external_id}/published_posts",
        access_token: page.access_token,
        fields: fields,
        summary: true,
        limit: LIMIT)
    end

    def self.upsert(page, post)
      post_id = post["id"].to_s
      return if post_id.blank?

      text = post["message"].presence || post["story"].presence
      published_at = parse_time(post["created_time"])
      picture = https_url(post["full_picture"])
      target = page.bulk_post_targets.find_by(external_post_id: post_id)

      if target
        target.bulk_post.update!(body: text) if text.present? && target.bulk_post.body != text
        target.update!(
          permalink: post["permalink_url"].presence,
          published_at: published_at || target.published_at,
          status: :published,
          provider_state: target.provider_state.merge("picture_url" => picture, "source" => "facebook")
        )
      else
        bulk = SocialMedia::BulkPost.new(
          organization: page.organization,
          owner: page.owner,
          body: text,
          status: :completed,
          target_scope: :explicit
        )
        bulk.save!(validate: text.present?)
        target = page.bulk_post_targets.create!(
          bulk_post: bulk,
          organization: page.organization,
          external_post_id: post_id,
          idempotency_key: "facebook:#{page.external_id}:#{post_id}",
          status: :published,
          permalink: post["permalink_url"].presence,
          published_at: published_at,
          provider_state: { "picture_url" => picture, "source" => "facebook" }
        )
      end

      record_counts(target, post)
      target
    end

    def self.record_counts(target, post)
      likes = number(post.dig("reactions", "summary", "total_count"))
      likes = number(post.dig("likes", "summary", "total_count")) if likes.nil?
      comments = number(post.dig("comments", "summary", "total_count"))
      shares = number(post.dig("shares", "count"))
      latest = target.latest_metric
      return if latest && latest.likes_count == likes && latest.comments_count == comments && latest.shares_count == shares

      target.post_metrics.create!(
        organization: target.organization,
        likes_count: likes,
        comments_count: comments,
        shares_count: shares,
        fetched_at: Time.current
      )
    end

    def self.write_posts_count(page, count)
      snapshot = page.metric_snapshots.find_or_initialize_by(captured_on: Date.current)
      snapshot.organization = page.organization
      snapshot.posts_count = count
      snapshot.save!
    end

    def self.number(value)
      return if value.nil?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end

    def self.parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def self.https_url(value)
      url = value.to_s
      url if url.start_with?("https://")
    end

    private_class_method :fetch, :request, :upsert, :record_counts, :write_posts_count, :number, :parse_time, :https_url
  end
end
