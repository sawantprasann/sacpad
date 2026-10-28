module Console
  class TalukasController < ReferenceController
    self.managed_model = Taluka
    self.managed_fields = %i[name native_name district_id]
    self.managed_title = "Taluka"

    helper_method :taluka_filters, :village_filters

    def index
      relation = managed_model.includes(:district).order(:name, :id)
      relation = relation.where(district_id: params[:district_id]) if params[:district_id].present?
      relation = relation.where("talukas.name ILIKE ?", like(params[:name])) if params[:name].present?
      @districts = District.order(:name)
      @records = relation
    end

    def show
      @record = managed_model.includes(:district).find(params[:id])
      @village_total = @record.villages.count
      @village_choices = @record.villages.order(:name)
      @villages = filtered_villages.load
    end

    def new
      @record = managed_model.new(district_id: params[:district_id])
      render "console/reference/new"
    end

    def create
      @record = managed_model.new(record_params)
      if @record.save
        redirect_to console_taluka_path(@record), notice: "Taluka created."
      else
        render "console/reference/new", status: :unprocessable_entity
      end
    end

    def update
      if @record.update(record_params)
        redirect_to console_taluka_path(@record), notice: "Taluka updated."
      else
        render "console/reference/edit", status: :unprocessable_entity
      end
    end

    private

    def filtered_villages
      relation = @record.villages
      relation = relation.where(id: params[:village_id]) if params[:village_id].present?
      if params[:police_station].present?
        relation = relation.where("villages.police_station ILIKE ?", like(params[:police_station]))
      end
      relation = relation.where("villages.pin_code ILIKE ?", like(params[:pin_code])) if params[:pin_code].present?
      relation
        .select("villages.*, COUNT(voters.id) AS voters_count")
        .left_joins(:voters)
        .group("villages.id")
        .preload(assembly: :loksabha)
        .order("villages.name", "villages.id")
    end

    def taluka_filters
      params.permit(:district_id, :name)
    end

    def village_filters
      params.permit(:village_id, :police_station, :pin_code)
    end

    def like(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value.strip)}%"
    end

    def reference_cancel_path
      @record&.persisted? ? console_taluka_path(@record) : console_talukas_path
    end
  end
end
