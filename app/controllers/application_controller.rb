class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Tenant isolation, layer 1: set the current organization explicitly per request.
  set_current_tenant_through_filter
  before_action :set_current_organization

  # A cross-tenant / not-permitted access surfaces as 404, never 403 (never confirm existence).
  rescue_from Pundit::NotAuthorizedError, with: :not_found

  private

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
