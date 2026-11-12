module GroundReports
  # Every work-inline row in the organization's constituency, with nidhi by status.
  class WorkInlinesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_ground_reports_access

    def index
      authorize VillageWork
      village_scope = filter_village(constituency_works)
      @nidhi_by_status = village_scope.nidhi_totals_by_status
      listed = filter_status(village_scope).includes(:village).order(created_at: :desc, id: :desc)
      @nidhi_sum = listed.sum(:nidhi_asked)

      respond_to do |format|
        format.html do
          @villages = current_user.organization.villages.order(:name)
          @pagy, @works = pagy(:offset, listed)
        end
        format.xlsx do
          @works = listed
          response.headers["Content-Disposition"] = "attachment; filename=work-inline.xlsx"
        end
      end
    end

    private

    def constituency_works
      policy_scope(VillageWork).kept.where(village_id: current_user.organization.villages.select(:id))
    end

    def filter_village(relation)
      name = params[:village].to_s.strip
      return relation if name.blank?

      relation.joins(:village).where(villages: { name: name })
    end

    def filter_status(relation)
      return relation unless VillageWork.statuses.key?(params[:status])

      relation.where(status: params[:status])
    end

    def require_ground_reports_access
      return if current_user.role.can_access?("ground_reports")

      redirect_to root_path, alert: t("ground_reports.no_access")
    end
  end
end
