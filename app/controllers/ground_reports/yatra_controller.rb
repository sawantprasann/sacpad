module GroundReports
  class YatraController < ApplicationController
    include LoadsVillage

    def update
      yatra = VillageYatra.find_or_initialize_by(village: @village)
      yatra.organization = current_user.organization
      yatra.updated_by = current_user
      yatra.assign_attributes(yatra_params)
      authorize yatra
      if yatra.save
        redirect_to ground_reports_village_path(@village), notice: "Yatra note saved."
      else
        redirect_to ground_reports_village_path(@village), alert: yatra.errors.full_messages.to_sentence
      end
    end

    private

    def yatra_params
      params.require(:village_yatra).permit(:notes)
    end
  end
end
