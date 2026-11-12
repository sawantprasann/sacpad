class PrRecordsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_pr_access

  def index
    @categories = PrCategory.active
    @category = @categories.find { |category| category.slug == params[:category] }
    relation = policy_scope(PrRecord).includes(:owner, entries: [ :pr_category, :media_platform, :links ])
    relation = relation.where(id: PrRecordEntry.where(pr_category_id: @category.id).select(:pr_record_id)) if @category
    if params[:q].present?
      term = "%#{params[:q].strip}%"
      relation = relation.where(
        "pr_records.title ILIKE :t OR pr_records.id IN (SELECT pr_record_id FROM pr_record_entries WHERE description ILIKE :t)",
        t: term
      )
    end
    relation = relation.order(Arel.sql(<<~SQL.squish), :id)
      COALESCE(
        (SELECT MAX(published_on) FROM pr_record_entries WHERE pr_record_entries.pr_record_id = pr_records.id),
        DATE '0001-01-01'
      ) DESC
    SQL

    respond_to do |format|
      format.html { @pagy, @records = pagy(:offset, relation) }
      format.xlsx do
        @records = relation
        response.headers["Content-Disposition"] = "attachment; filename=pr_records.xlsx"
      end
    end
  end

  def show
    @record = policy_scope(PrRecord).includes(entry_includes).find(params[:id])
    authorize @record
  end

  def new
    @record = PrRecord.new
    @record.entries.build(
      pr_category: PrCategory.active.find_by(slug: params[:category]),
      published_on: Date.current,
      sentiment: :neutral
    )
    authorize @record
    prepare_form
  end

  def create
    @record = PrRecord.new(record_params)
    @record.owner = current_user
    authorize @record
    if @record.save
      redirect_to pr_records_path(category: @record.entries.first&.pr_category&.slug),
                  notice: t("pr.logged", number: @record.record_number)
    else
      prepare_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @record = policy_scope(PrRecord).includes(entry_includes).find(params[:id])
    authorize @record, :edit?
    prepare_form
  end

  def update
    @record = policy_scope(PrRecord).includes(entry_includes).find(params[:id])
    authorize @record, :update?
    if @record.update(record_params)
      redirect_to pr_record_path(@record), notice: t("pr.updated")
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

  def destroy_entry
    @record = policy_scope(PrRecord).includes(entries: :pr_category).find(params[:pr_record_id])
    authorize @record, :update?
    entry = @record.entries.find(params[:entry_id])
    if @record.entries.one?
      message = t("pr.last_category")
      respond_to do |format|
        format.html { redirect_to pr_record_path(@record), alert: message }
        format.json { render json: { error: message }, status: :unprocessable_entity }
      end
      return
    end

    name = entry.pr_category.name
    entry.destroy!
    respond_to do |format|
      format.html { redirect_to pr_record_path(@record), notice: t("pr.category_removed", name: name) }
      format.json { head :no_content }
    end
  end

  private

  def record_params
    params.require(:pr_record).permit(:title, entries_attributes: [
      :id, :description, :url, :thumbnail_url, :published_on, :sentiment,
      :pr_category_id, :media_platform_id, :media_platform_name, :_destroy,
      { attachments: [] },
      { outdoor_ad_counts_attributes: [ :id, :outdoor_ad_type_id, :count, :_destroy ] },
      { podcast_attributes: [ :id, :recording_date, :_destroy ] },
      { links_attributes: [ :id, :url, :thumbnail_url, :_destroy ] }
    ])
  end

  def prepare_form
    @categories = PrCategory.active
    @platforms = MediaPlatform.active.order(:name)
    if @record.entries.reject(&:marked_for_destruction?).empty?
      @record.entries.build(published_on: Date.current, sentiment: :neutral)
    end
    @record.entries.each do |entry|
      next if entry.marked_for_destruction?

      if entry.links.reject(&:marked_for_destruction?).empty?
        entry.links.build(url: entry.url, thumbnail_url: entry.thumbnail_url)
      end
      entry.outdoor_ad_counts.build if entry.outdoor_ad_counts.reject(&:marked_for_destruction?).empty?
    end
  end

  def entry_includes
    { entries: [ :pr_category, :media_platform, :links, :podcast, { outdoor_ad_counts: :outdoor_ad_type }, { attachments_attachments: :blob } ] }
  end

  def require_pr_access
    redirect_to root_path, alert: t("pr.no_access") unless
      current_user.role.can_access?("pr")
  end
end
