module Console
  class LoksabhasController < ReferenceController
    self.managed_model = Loksabha
    self.managed_fields = %i[state_id district_id name constituency_no]
    self.managed_title = "Loksabha"

    helper_method :loksabha_filters, :assembly_filters

    def index
      relation = managed_model.includes(:state, :district).order(:id)
      if params[:state].present?
        relation = relation.where("states.name ILIKE ?", like(params[:state])).references(:state)
      end
      if params[:district].present?
        relation = relation.where("districts.name ILIKE ?", like(params[:district])).references(:district)
      end
      relation = relation.where("loksabhas.name ILIKE ?", like(params[:name])) if params[:name].present?
      if params[:constituency_no].present?
        relation = relation.where("loksabhas.constituency_no ILIKE ?", like(params[:constituency_no]))
      end
      @records = relation
    end

    def show
      @loksabha = managed_model.includes(:state, :district).find(params[:id])
      @assembly_total = @loksabha.assemblies.count
      @assemblies = filtered_assemblies.load
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
      params.permit(:state, :district, :name, :constituency_no)
    end

    def assembly_filters
      params.permit(:name, :constituency_no)
    end

    def like(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value.strip)}%"
    end
  end
end
