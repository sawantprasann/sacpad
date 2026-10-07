module GroundReports
  class WorshipPlacesController < ApplicationController
    include LoadsVillage

    def create
      place = @village.worship_places.new(place_params)
      place.organization = current_user.organization
      authorize place
      if place.save
        redirect_to ground_reports_village_path(@village), notice: "Worship place added."
      else
        redirect_to ground_reports_village_path(@village), alert: place.errors.full_messages.to_sentence
      end
    end

    private

    def place_params
      params.require(:worship_place).permit(:name, :place_type, :notes)
    end
  end
end
