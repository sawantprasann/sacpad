module Console
  class DistrictsController < ReferenceController
    self.managed_model = District
    self.managed_fields = %i[name state_id cd]
    self.managed_title = "District"

    helper_method :district_filters, :taluka_filters

    def index
      relation = managed_model.includes(:state).order(:name, :id)
      relation = relation.where(state_id: params[:state_id]) if params[:state_id].present?
      relation = relation.where("districts.name ILIKE ?", like(params[:name])) if params[:name].present?
      @states = State.order(:name)
      @records = relation
    end

    def show
      @record = managed_model.includes(:state).find(params[:id])
      @taluka_total = @record.talukas.count
      @loksabha_total = @record.loksabhas.count
      @taluka_choices = @record.talukas.order(:name)
      @talukas = filtered_talukas.load
      @loksabhas = filtered_loksabhas.load
    end

    def create
      @record = managed_model.new(record_params)
      if @record.save
        redirect_to console_district_path(@record), notice: "District created."
      else
        render "console/reference/new", status: :unprocessable_entity
      end
    end

    def update
      if @record.update(record_params)
        redirect_to console_district_path(@record), notice: "District updated."
      else
        render "console/reference/edit", status: :unprocessable_entity
      end
    end

    private

    def filtered_talukas
      relation = @record.talukas
      relation = relation.where(id: params[:taluka_id]) if params[:taluka_id].present?
      relation
        .select("talukas.*, COUNT(villages.id) AS villages_count")
        .left_joins(:villages)
        .group("talukas.id")
        .order("talukas.name", "talukas.id")
    end

    def filtered_loksabhas
      @record.loksabhas
        .select("loksabhas.*, COUNT(assemblies.id) AS assemblies_count")
        .left_joins(:assemblies)
        .group("loksabhas.id")
        .order(:constituency_no, :id)
    end

    def district_filters
      params.permit(:state_id, :name)
    end

    def taluka_filters
      params.permit(:taluka_id)
    end

    def like(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value.strip)}%"
    end

    def reference_cancel_path
      @record&.persisted? ? console_district_path(@record) : console_districts_path
    end
  end
end
