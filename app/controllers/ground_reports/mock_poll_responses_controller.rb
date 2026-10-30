module GroundReports
  class MockPollResponsesController < ApplicationController
    include LoadsVillage

    before_action :set_survey, only: %i[edit update destroy]
    before_action :load_politicians, only: %i[edit update]

    def create
      survey = @village.mock_poll_responses.new(response_params)
      survey.organization = current_user.organization
      survey.created_by = current_user
      authorize survey
      if survey.save
        redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.survey_recorded")
      else
        redirect_to ground_reports_village_path(@village), alert: survey.errors.full_messages.to_sentence
      end
    end

    def edit; end

    def update
      if @survey.update(response_params)
        redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.survey_updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @survey.discard_by(current_user)
      redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.survey_deleted")
    end

    private

    def set_survey
      @survey = @village.mock_poll_responses.kept.find(params[:id])
      authorize @survey
    end

    def load_politicians
      @politicians = Politician.order(:name)
    end

    def response_params
      params.require(:mock_poll_response).permit(
        :politician_id, :respondent_name, :respondent_mobile, :preference_basis, :vote_choice, :note
      )
    end
  end
end
