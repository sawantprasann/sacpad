module VoterLists
  class TalukasController < BaseController
    helper_method :taluka_filters, :village_filters

    def index
      @taluka_choices = organization_talukas.includes(:district).order(:name, :id)
      @talukas = filtered_talukas.load
    end

    def show
      @taluka = organization_talukas.includes(:district).find(params[:id])
      scope = organization_villages.where(taluka_id: @taluka.id)
      @village_total = scope.count
      @village_choices = scope.order(:name)
      @pagy, @villages = pagy(:offset, filtered_villages(scope))
    end

    private

    def filtered_talukas
      relation = organization_talukas
      relation = relation.where(id: params[:taluka_id]) if params[:taluka_id].present?
      relation
        .select("talukas.*, COUNT(villages.id) AS villages_count")
        .joins(:villages)
        .where(villages: { id: organization_villages.select(:id) })
        .group("talukas.id")
        .preload(:district)
        .order("talukas.name", "talukas.id")
    end

    def filtered_villages(scope)
      relation = scope
      relation = relation.where(id: params[:village_id]) if params[:village_id].present?
      if params[:police_station].present?
        term = like(params[:police_station])
        relation = relation.left_joins(:police_station_record).where(
          "villages.police_station ILIKE :term OR police_stations.native_name ILIKE :term",
          term: term
        )
      end
      relation = relation.where("villages.pin_code ILIKE ?", like(params[:pin_code])) if params[:pin_code].present?
      relation
        .select("villages.*, COUNT(voters.id) AS voters_count")
        .left_joins(:voters)
        .group("villages.id")
        .preload(:police_station_record, assembly: :loksabha)
        .order("villages.name", "villages.id")
    end

    def taluka_filters
      params.permit(:taluka_id)
    end

    def village_filters
      params.permit(:village_id, :police_station, :pin_code)
    end
  end
end
