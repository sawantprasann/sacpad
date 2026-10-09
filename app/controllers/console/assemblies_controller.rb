module Console
  class AssembliesController < ReferenceController
    self.managed_model = Assembly
    self.managed_fields = %i[name constituency_no first_part last_part]
    self.managed_title = "Assembly"

    prepend_before_action :set_loksabha
    skip_before_action :set_record
    before_action :set_record, only: %i[show edit update destroy]

    helper_method :village_filters

    def show
      @village_total = @record.villages.count
      @villages = filtered_villages.load
    end

    def new
      @record = @loksabha.assemblies.new
      render "console/reference/new"
    end

    def create
      @record = @loksabha.assemblies.new(record_params)
      if @record.save
        redirect_to console_loksabha_assembly_path(@loksabha, @record), notice: "Assembly created."
      else
        render "console/reference/new", status: :unprocessable_entity
      end
    end

    def update
      if @record.update(record_params)
        redirect_to console_loksabha_assembly_path(@loksabha, @record), notice: "Assembly updated."
      else
        render "console/reference/edit", status: :unprocessable_entity
      end
    end

    def destroy
      @record.destroy
      redirect_to console_loksabha_path(@loksabha), notice: "Assembly deleted."
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
      redirect_to console_loksabha_path(@loksabha), alert: "Can't delete — it still has dependent records."
    end

    private

    def set_loksabha
      @loksabha = Loksabha.find(params[:loksabha_id])
    end

    def set_record
      @record = @loksabha.assemblies.find(params[:id])
    end

    def filtered_villages
      relation = @record.villages
      relation = relation.where("villages.name ILIKE ?", like(params[:name])) if params[:name].present?
      if params[:police_station].present?
        relation = relation.where("villages.police_station ILIKE ?", like(params[:police_station]))
      end
      relation = relation.where("villages.pin_code ILIKE ?", like(params[:pin_code])) if params[:pin_code].present?
      relation = relation.where("talukas.name ILIKE ?", like(params[:taluka])) if params[:taluka].present?
      relation
        .select("villages.*, talukas.name AS taluka_name, COUNT(voters.id) AS voters_count")
        .left_joins(:voters, :taluka)
        .group("villages.id, talukas.name")
        .order(:name, :id)
    end

    def village_filters
      params.permit(:name, :taluka, :police_station, :pin_code)
    end

    def like(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value.strip)}%"
    end
  end
end
