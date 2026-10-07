module GroundReports
  class ImportsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_ground_reports_access

    def new
      @import = Import.new(kind: :report)
      authorize @import
    end

    def create
      @import = Import.new(import_params)
      @import.organization = current_user.organization
      @import.user = current_user
      authorize @import
      if @import.save
        ImportGroundReportsJob.perform_later(@import.id)
        redirect_to ground_reports_import_path(@import), notice: "Import started."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @import = Import.find(params[:id])
      authorize @import
    end

    private

    def import_params
      params.require(:import).permit(:kind, :file)
    end

    def require_ground_reports_access
      return if current_user.role.can_access?("ground_reports")

      redirect_to root_path, alert: "You don't have access to Ground Reports."
    end
  end
end
