module GroundReports
  class PoliticalPositionsController < ApplicationController
    include LoadsVillage

    before_action :set_position, only: %i[edit update destroy]
    before_action :load_parties, only: %i[edit update]

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

    def edit; end

    def update
      if @position.update(position_params)
        redirect_to ground_reports_village_path(@village), notice: "Political position updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @position.discard_by(current_user)
      redirect_to ground_reports_village_path(@village), notice: "Political position deleted."
    end

    private

    def set_position
      @position = @village.political_positions.kept.find(params[:id])
      authorize @position
    end

    def load_parties
      @parties = Party.order(:name)
    end

    def position_params
      params.require(:village_political_position).permit(
        :party_id, :representative_name, :position_title, :started_at, :ended_at
      )
    end
  end
end
