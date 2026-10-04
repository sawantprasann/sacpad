module Console
  # Base for every Platform Console controller (Admin-only, §3.0/§5a).
  # Inherits ActionController::Base directly (NOT ApplicationController) so it never picks up
  # the org-side acts_as_tenant filter — the Console operates across organizations, explicitly
  # via ActsAsTenant.without_tenant where it needs org data (Story 0.11), not a bypass flag.
  class BaseController < ActionController::Base
    include Pundit::Authorization
    include Auditable

    allow_browser versions: :modern
    before_action :authenticate_admin!
    layout "console"

    rescue_from Pundit::NotAuthorizedError, with: :not_found

    private

    def not_found
      raise ActionController::RoutingError, "Not Found"
    end
  end
end
