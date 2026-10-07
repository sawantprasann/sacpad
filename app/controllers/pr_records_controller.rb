class PrRecordsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_pr_access

  def index
    @category = PrCategory.active.find_by(slug: params[:category])
    relation = policy_scope(PrRecord).includes(:pr_category, :owner)
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
  end

  def create
    @record = PrRecord.new(record_params)
    @record.owner = current_user
    authorize @record
    if @record.save
      redirect_to pr_records_path(category: @record.pr_category&.slug),
                  notice: "PR record ##{@record.record_number} logged."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @record = policy_scope(PrRecord).find(params[:id])
    authorize @record, :edit?
  end

  def update
    @record = policy_scope(PrRecord).find(params[:id])
    authorize @record, :update?
    if @record.update(record_params)
      redirect_to pr_record_path(@record), notice: "PR record updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def record_params
    params.require(:pr_record).permit(:title, :description, :url, :thumbnail_url,
      :published_on, :sentiment, :pr_category_id, :media_platform_id,
      :media_platform_name, attachments: [],
      outdoor_ad_counts_attributes: [:id, :outdoor_ad_type_id, :count, :_destroy],
      podcast_attributes: [:id, :recording_date, :_destroy])
  end

  def require_pr_access
    redirect_to root_path, alert: "You don't have access to PR records." unless
      current_user.role.can_access?("pr")
  end
end
