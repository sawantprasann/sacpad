module GroundReports
  # Shared gate for village-fact controllers: module access, then a constituency village.
  module LoadsVillage
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_user!
      before_action :require_ground_reports_access
      before_action :set_village
    end

    private

    def set_village
      @village = current_user.organization.villages.find(params[:village_id])
    end

    def require_ground_reports_access
      return if current_user.role.can_access?("ground_reports")

      redirect_to root_path, alert: "You don't have access to Ground Reports."
    end
  end
end
