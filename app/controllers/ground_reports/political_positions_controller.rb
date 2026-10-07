module GroundReports
  class PoliticalPositionsController < ApplicationController
    include LoadsVillage

    def create
      position = @village.political_positions.new(position_params)
      position.organization = current_user.organization
      authorize position
      if position.save
        redirect_to ground_reports_village_path(@village), notice: "Political position recorded."
      else
        redirect_to ground_reports_village_path(@village), alert: position.errors.full_messages.to_sentence
      end
    end

    private

    def position_params
      params.require(:village_political_position).permit(
        :party_id, :representative_name, :position_title, :started_at, :ended_at
      )
    end
  end
end
