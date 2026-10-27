module Console
  class LoksabhasController < ReferenceController
    self.managed_model = Loksabha
    self.managed_fields = %i[state_id district_id name constituency_no]
    self.managed_title = "Loksabha"

    helper_method :loksabha_filters, :assembly_filters

    def index
      relation = managed_model.includes(:state, :district).order(:id)
      relation = relation.where(state_id: params[:state_id]) if params[:state_id].present?
      relation = relation.where(district_id: params[:district_id]) if params[:district_id].present?
      relation = relation.where("loksabhas.name ILIKE ?", like(params[:name])) if params[:name].present?
      if params[:constituency_no].present?
        relation = relation.where("loksabhas.constituency_no ILIKE ?", like(params[:constituency_no]))
      end
      @states = State.order(:name)
      @districts = District.order(:name)
      @records = relation
    end

    def show
      @loksabha = managed_model.includes(:state, :district).find(params[:id])
      @assembly_total = @loksabha.assemblies.count
      @assemblies = filtered_assemblies.load
      @election_results = @loksabha.election_results.includes(:gained_from_party, candidates: :party).order(year: :desc)
    end

    def create
      @record = managed_model.new(record_params)
      if @record.save
        redirect_to console_loksabha_path(@record), notice: "Loksabha created."
      else
        render "console/reference/new", status: :unprocessable_entity
      end
    end

    def update
      if @record.update(record_params)
        redirect_to console_loksabha_path(@record), notice: "Loksabha updated."
      else
        render "console/reference/edit", status: :unprocessable_entity
      end
    end

    private

    def filtered_assemblies
      relation = @loksabha.assemblies
      relation = relation.where("assemblies.name ILIKE ?", like(params[:name])) if params[:name].present?
      if params[:constituency_no].present?
        relation = relation.where("assemblies.constituency_no ILIKE ?", like(params[:constituency_no]))
      end
      relation
        .select("assemblies.*, COUNT(villages.id) AS villages_count")
        .left_joins(:villages)
        .group("assemblies.id")
        .order(:constituency_no, :id)
    end

    def loksabha_filters
      params.permit(:state_id, :district_id, :name, :constituency_no)
    end

    def assembly_filters
      params.permit(:name, :constituency_no)
    end

    def like(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value.strip)}%"
    end

    def reference_cancel_path
      @record&.persisted? ? console_loksabha_path(@record) : console_loksabhas_path
    end
  end
end
