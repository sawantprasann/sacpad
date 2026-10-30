module GroundReports
  class WorshipPlacesController < ApplicationController
    include LoadsVillage

    before_action :set_place, only: %i[edit update destroy]

    def create
      place = @village.worship_places.new(place_params)
      place.organization = current_user.organization
      authorize place
      if place.save
        redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.worship_added")
      else
        redirect_to ground_reports_village_path(@village), alert: place.errors.full_messages.to_sentence
      end
    end

    def edit; end

    def update
      if @place.update(place_params)
        redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.worship_updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @place.discard_by(current_user)
      redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.worship_deleted")
    end

    private

    def set_place
      @place = @village.worship_places.kept.find(params[:id])
      authorize @place
    end

    def place_params
      params.require(:worship_place).permit(:name, :place_type, :notes)
    end
  end
end
