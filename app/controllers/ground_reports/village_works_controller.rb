module GroundReports
  class VillageWorksController < ApplicationController
    include LoadsVillage

    before_action :set_work, only: %i[edit update destroy]

    def create
      work = @village.village_works.new(work_params)
      work.organization = current_user.organization
      authorize work
      if work.save
        redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.work_added")
      else
        redirect_to ground_reports_village_path(@village), alert: work.errors.full_messages.to_sentence
      end
    end

    def edit; end

    def update
      if @work.update(work_params)
        redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.work_updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @work.discard_by(current_user)
      redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.work_deleted")
    end

    private

    def set_work
      @work = @village.village_works.kept.find(params[:id])
      authorize @work
    end

    def work_params
      permitted = params.require(:village_work).permit(
        :title, :concern_person, :nidhi_asked, :nidhi_category, :nidhi_category_name,
        :work_order_created_at, :status, attachments: []
      )
      files = Array(permitted[:attachments]).reject(&:blank?)
      files.present? ? permitted.merge(attachments: files) : permitted.except(:attachments)
    end
  end
end
