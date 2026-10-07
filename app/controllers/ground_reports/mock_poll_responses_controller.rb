module GroundReports
  class MockPollResponsesController < ApplicationController
    include LoadsVillage

    def create
      survey = @village.mock_poll_responses.new(response_params)
      survey.organization = current_user.organization
      survey.created_by = current_user
      authorize survey
      if survey.save
        redirect_to ground_reports_village_path(@village), notice: "Survey response recorded."
      else
        redirect_to ground_reports_village_path(@village), alert: survey.errors.full_messages.to_sentence
      end
    end

    private

    def response_params
      params.require(:mock_poll_response).permit(
        :politician_id, :respondent_name, :respondent_mobile, :preference_basis, :vote_choice, :note
      )
    end
  end
end
