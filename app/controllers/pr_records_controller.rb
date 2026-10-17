class PrRecordsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_pr_access

  def index
    @categories = PrCategory.active
    @category = @categories.find { |category| category.slug == params[:category] }
    relation = policy_scope(PrRecord).includes(:pr_category, :owner, :media_platform)
    relation = relation.where(pr_category_id: @category.id) if @category
    if params[:q].present?
      term = "%#{params[:q].strip}%"
      relation = relation.where("title ILIKE :t OR description ILIKE :t", t: term)
    end
    relation = relation.order(published_on: :desc, id: :desc)

    respond_to do |format|
      format.html { @pagy, @records = pagy(:offset, relation) }
      format.xlsx do
        @records = relation
        response.headers["Content-Disposition"] = "attachment; filename=pr_records.xlsx"
      end
    end
  end

  def show
    @record = policy_scope(PrRecord).find(params[:id])
    authorize @record
  end

  def new
    @record = PrRecord.new(pr_category: PrCategory.active.find_by(slug: params[:category]))
    authorize @record
    prepare_form
  end

  def create
    @record = PrRecord.new(record_params)
    @record.owner = current_user
    authorize @record
    if @record.save
      redirect_to pr_records_path(category: @record.pr_category&.slug),
                  notice: "PR record ##{@record.record_number} logged."
    else
      prepare_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @record = policy_scope(PrRecord).find(params[:id])
    authorize @record, :edit?
    prepare_form
  end

  def update
    @record = policy_scope(PrRecord).find(params[:id])
    authorize @record, :update?
    if @record.update(record_params)
      redirect_to pr_record_path(@record), notice: "PR record updated."
    else
      prepare_form
      render :edit, status: :unprocessable_entity
    end
  end

  def thumbnail
    authorize PrRecord, :create?
    url = PrRecords::FetchThumbnail.call(params[:url])
    render json: { thumbnail_url: url }
  rescue PrRecords::FetchThumbnail::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def record_params
    params.require(:pr_record).permit(:title, :description, :url, :thumbnail_url,
      :published_on, :sentiment, :pr_category_id, :media_platform_id,
      :media_platform_name, attachments: [],
      outdoor_ad_counts_attributes: [ :id, :outdoor_ad_type_id, :count, :_destroy ],
      podcast_attributes: [ :id, :recording_date, :_destroy ],
      links_attributes: [ :id, :url, :thumbnail_url, :_destroy ])
  end

  def prepare_form
    @categories = PrCategory.active
    @platforms = MediaPlatform.active.order(:name)
    if @record.links.empty?
      @record.links.build(url: @record.url, thumbnail_url: @record.thumbnail_url)
    end
    @record.outdoor_ad_counts.build if @record.outdoor_ad_counts.empty?
  end

  def require_pr_access
    redirect_to root_path, alert: "You don't have access to PR records." unless
      current_user.role.can_access?("pr")
  end
end
