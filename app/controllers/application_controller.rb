class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Auditable
  include Pagy::Method   # pagination helper (`pagy :offset, relation`) — pagy 43.x API

  # Devise pages (sign-in, password reset) use a standalone centered auth layout — NO app shell
  # (no sidebar on the login page). Everything else uses the themed application shell.
  layout :layout_by_controller

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Tenant isolation, layer 1: set the current organization explicitly per request.
  set_current_tenant_through_filter
  before_action :set_current_organization

  # A cross-tenant / not-permitted access surfaces as 404, never 403 (never confirm existence).
  rescue_from Pundit::NotAuthorizedError, with: :not_found

  # --- Devise redirect targets, scope-aware (fixes Admin bouncing to the User login) ---
  # Admins live in the Platform Console; everyone else on the org side.
  def after_sign_in_path_for(resource)
    resource.is_a?(Admin) ? console_root_path : super
  end

  # Used for the "already authenticated" redirect when hitting a sign-in page again.
  def signed_in_root_path(resource_or_scope)
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    scope == :admin ? console_root_path : super
  end

  def after_sign_out_path_for(resource_or_scope)
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    scope == :admin ? new_admin_session_path : super
  end

  private

  def layout_by_controller
    devise_controller? ? "auth" : "application"
  end

  # Tenant = the signed-in user's organization (Story 0.7). When not signed in, nil is safe —
  # org-side controllers touch no tenant-scoped models until authenticated, and any accidental
  # scoped query with no tenant RAISES (require_tenant = true) by design.
  def set_current_organization
    set_current_tenant(current_user&.organization)
  end

  def not_found
    raise ActionController::RoutingError, "Not Found"
  end
end
