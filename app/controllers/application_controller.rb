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
  before_action :set_locale

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

  # The platform console stays English. Org pages follow the signed-in user's
  # saved language, then the locale cookie, then English.
  def set_locale
    if request.path.start_with?("/console")
      I18n.locale = I18n.default_locale
      return
    end

    locale = preferred_user_locale || cookie_locale || I18n.default_locale
    I18n.locale = locale
    sync_locale_cookie(locale) if user_signed_in?
  end

  def preferred_user_locale
    return unless user_signed_in?

    normalize_locale(current_user.preferred_locale)
  end

  def cookie_locale
    normalize_locale(cookies[:locale])
  end

  def normalize_locale(value)
    value = value.to_s
    I18n.available_locales.map(&:to_s).include?(value) ? value.to_sym : nil
  end

  def sync_locale_cookie(locale)
    return if cookies[:locale] == locale.to_s

    cookies.permanent[:locale] = { value: locale.to_s, httponly: true, same_site: :lax }
  end

  def not_found
    raise ActionController::RoutingError, "Not Found"
  end
end
