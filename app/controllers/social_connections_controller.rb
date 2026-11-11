class SocialConnectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_social_access
  before_action :require_org_admin, only: %i[create failure choose save destroy]

  def index
    @pages = policy_scope(SocialMedia::SocialPage).includes(:owner).order(:name)
    @facebook_ready = MetaApi.configured?
  end

  def show
    @page = policy_scope(SocialMedia::SocialPage).includes(:owner, :karyakarta_user, :politician).find(params[:id])
    authorize @page
    refresh_facebook_posts
    @targets = @page.bulk_post_targets
      .joins(:bulk_post)
      .merge(SocialMedia::BulkPost.kept)
      .includes(bulk_post: [ :owner, { images_attachments: :blob } ])
      .order(Arel.sql("COALESCE(bulk_post_targets.published_at, bulk_post_targets.created_at) DESC"))
    @metrics = SocialMedia::PostMetric.latest_per_target
      .where(bulk_post_target_id: @targets.map(&:id))
      .index_by(&:bulk_post_target_id)
    @snapshot = @page.metric_snapshots.order(captured_on: :desc).first
    reach_parts = [ @snapshot&.organic_reach, @snapshot&.paid_reach ].compact
    @page_totals = {
      followers: @snapshot&.followers_count,
      posts: @snapshot&.posts_count || @targets.size,
      views: @snapshot&.views_count,
      reach: reach_parts.empty? ? nil : reach_parts.sum
    }
  end

  def create
    auth = request.env["omniauth.auth"]
    unless auth&.provider == "facebook"
      redirect_to social_connections_path, alert: t("social.unsupported")
      return
    end

    pending = SocialConnections::ConnectFacebook.call(user: current_user, auth: auth)
    if pending
      redirect_to choose_social_connections_path(pending_id: pending.id)
    else
      redirect_to social_connections_path, alert: t("social.no_pages")
    end
  rescue MetaApi::Graph::Error => e
    Rails.logger.warn("[social] connect failed: #{e.class}: #{e.message.to_s.truncate(200)}")
    redirect_to social_connections_path, alert: t("social.failed")
  end

  def failure
    redirect_to social_connections_path, alert: t("social.cancelled")
  end

  def choose
    pending = fresh_pending
    @pending_id = pending.id
    @pages = present_pages(pending)
  end

  def save
    pending = fresh_pending
    saved = SocialConnections::SaveFacebookPages.call(
      user: current_user,
      pending: pending,
      page_ids: params[:page_ids],
      instagram_ids: params[:instagram_ids]
    )
    if saved.empty?
      redirect_to choose_social_connections_path(pending_id: pending.id), alert: t("social.pick_one")
    else
      redirect_to social_connections_path, notice: t("social.connected_notice")
    end
  end

  def new
    authorize SocialMedia::SocialPage, :publish?
    @publish_pages = policy_scope(SocialMedia::SocialPage).order(:name).select { |page| SocialConnections::PublishFacebookText.ready?(page) }
  end

  def publish
    authorize SocialMedia::SocialPage, :publish?
    images, video = split_media(params.dig(:bulk_post, :media))
    post = SocialConnections::PublishFacebookText.call(
      user: current_user,
      body: params.dig(:bulk_post, :body),
      page_ids: params[:page_ids],
      images: images,
      video: video
    )
    notice = if post.publish_partially_failed?
      t("social.publish_partial")
    else
      t("social.publish_sent")
    end
    alert = if post.publish_failed?
      post.targets.reload.filter_map(&:error_message).first.presence || t("social.publish_failed")
    end
    redirect_to social_connections_path, notice: alert.nil? ? notice : nil, alert: alert
  rescue SocialConnections::PublishFacebookText::NeedText
    redirect_to new_social_connection_path, alert: t("social.publish_need_text")
  rescue SocialConnections::PublishFacebookText::NeedMedia
    redirect_to new_social_connection_path, alert: t("social.publish_need_media")
  rescue SocialConnections::PublishFacebookText::NothingSelected
    redirect_to new_social_connection_path, alert: t("social.publish_pick_page")
  rescue SocialConnections::PublishFacebookText::MixedMedia
    redirect_to new_social_connection_path, alert: t("social.publish_mixed")
  end

  def sync
    @page = policy_scope(SocialMedia::SocialPage).find(params[:id])
    authorize @page, :show?
    SocialConnections::ImportFacebookPosts.call(page: @page)
    redirect_to social_connection_path(@page), notice: t("social.posts_refreshed")
  rescue MetaApi::Graph::Error => e
    record_page_error(@page, e)
    redirect_to social_connection_path(@page), alert: t("social.posts_refresh_failed")
  end

  def destroy
    page = policy_scope(SocialMedia::SocialPage).find(params[:id])
    authorize page
    page.disconnect!
    if page.facebook?
      policy_scope(SocialMedia::SocialPage).instagram.where(parent_external_id: page.external_id).find_each(&:disconnect!)
    end
    redirect_to social_connections_path, notice: t("social.disconnected")
  end

  private

  def require_social_access
    authorize SocialMedia::SocialPage, :index?
  end

  def require_org_admin
    authorize SocialMedia::SocialPage, :connect?
  end

  def refresh_facebook_posts
    return unless SocialConnections::ImportFacebookPosts.due?(@page)

    SocialConnections::ImportFacebookPosts.call(page: @page)
  rescue MetaApi::Graph::Error => e
    record_page_error(@page, e)
    flash.now[:alert] = t("social.posts_refresh_failed")
  end

  def record_page_error(page, error)
    return if page.nil?

    Rails.logger.warn("[social] posts failed: #{error.class}: #{error.message.to_s.truncate(200)}")
    attrs = { last_error: error.message.to_s.truncate(200), last_error_at: Time.current }
    attrs[:status] = :needs_reauth if error.token_error?
    page.update!(attrs)
  end

  # One picker. Photos and a video go to different Facebook calls, so a post
  # is up to 4 photos or a single video.
  def split_media(files)
    images = []
    video = nil
    Array(files).reject(&:blank?).each do |file|
      type = file.content_type.to_s
      if type.start_with?("image/")
        images << file
      elsif type.start_with?("video/")
        raise SocialConnections::PublishFacebookText::MixedMedia if video
        video = file
      else
        raise SocialConnections::PublishFacebookText::MixedMedia
      end
    end
    raise SocialConnections::PublishFacebookText::MixedMedia if images.any? && video

    [ images.first(4), video ]
  end

  def fresh_pending
    current_user.pending_connections.fresh.find(params[:pending_id])
  end

  # id, name, and the linked Instagram username. Never the token.
  def present_pages(pending)
    pending.items.map do |page|
      ig = page["instagram_business_account"]
      {
        id: page["id"].to_s,
        name: page["name"],
        category: page["category"],
        username: page["username"],
        instagram: ig && ig["id"].present? ? { id: ig["id"].to_s, username: ig["username"], name: ig["name"] } : nil
      }
    end
  end

end
