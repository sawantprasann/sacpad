class SocialPostsController < ApplicationController
  PAGE_SIZE = 20

  before_action :authenticate_user!
  before_action :set_post, only: %i[edit update destroy]

  def index
    authorize SocialMedia::SocialPage, :index?
    relation = SocialMedia::BulkPost.kept
      .where(id: SocialMedia::BulkPostTarget.select(:bulk_post_id))
      .includes(targets: :social_page)
      .order(Arel.sql(<<~SQL.squish))
        (
          SELECT MAX(COALESCE(bulk_post_targets.published_at, bulk_post_targets.created_at))
          FROM bulk_post_targets
          WHERE bulk_post_targets.bulk_post_id = bulk_posts.id
        ) DESC, bulk_posts.id DESC
      SQL
    @pagy, @posts = pagy(:offset, relation, limit: PAGE_SIZE)
  end

  def edit
    authorize SocialMedia::SocialPage, :publish?
  end

  def update
    authorize SocialMedia::SocialPage, :publish?
    result = SocialConnections::UpdatePost.call(post: @post, body: params.dig(:bulk_post, :body))
    if result.saved
      redirect_to social_posts_path, flash_for(result.failed, "social.post_updated", "social.post_updated_partial")
    else
      @post.body = params.dig(:bulk_post, :body)
      flash.now[:alert] = t("social.post_update_failed", pages: page_list(result.failed))
      render :edit, status: :unprocessable_entity
    end
  rescue SocialConnections::PublishFacebookText::NeedText
    flash.now[:alert] = t("social.publish_need_text")
    render :edit, status: :unprocessable_entity
  end

  def destroy
    authorize SocialMedia::SocialPage, :publish?
    result = SocialConnections::DeletePost.call(post: @post, actor: current_user)
    redirect_to social_posts_path, flash_for(result.failed, "social.post_deleted", "social.post_deleted_partial")
  end

  private

  def set_post
    @post = SocialMedia::BulkPost.kept.includes(targets: :social_page).find(params[:id])
  end

  def flash_for(failed, notice_key, alert_key)
    return { notice: t(notice_key) } if failed.empty?

    { alert: t(alert_key, pages: page_list(failed)) }
  end

  def page_list(targets)
    targets.map { |target| "#{page_name(target)}: #{target.error_message}" }.join("; ").truncate(300)
  end

  def page_name(target)
    target.social_page.name.presence || t("social.unnamed")
  end
end
