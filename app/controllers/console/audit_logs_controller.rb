module Console
  # Cross-org audit log view (§7a/§8a, Story 0.11). Queryable by actor/org/action.
  # ops-tier admins see only their assigned organizations' entries.
  class AuditLogsController < BaseController
    def index
      scope = ActivityLog.order(created_at: :desc)
      scope = scope.where(organization_id: current_admin.organizations.select(:id)) unless current_admin.full?
      scope = scope.where(action: params[:action_filter]) if params[:action_filter].present?
      scope = scope.where(organization_id: params[:organization_id]) if params[:organization_id].present?
      scope = scope.where(actor_type: params[:actor_type]) if params[:actor_type].present?
      @logs = scope.limit(200)
    end
  end
end
