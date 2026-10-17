module GroundReports
  class VillageWorksController < ApplicationController
    include LoadsVillage

    def create
      work = @village.village_works.new(work_params)
      work.organization = current_user.organization
      authorize work
      if work.save
        redirect_to ground_reports_village_path(@village), notice: "Work inline added."
      else
        redirect_to ground_reports_village_path(@village), alert: work.errors.full_messages.to_sentence
      end
    end

    private

    def work_params
      params.require(:village_work).permit(
        :title, :concern_person, :nidhi_asked, :nidhi_category, :nidhi_category_name,
        :work_order_created_at, :status, attachments: []
      )
    end
  end
end
