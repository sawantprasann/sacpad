module Console
  # Base for every Platform Console controller (Admin-only, §3.0/§5a).
  # Inherits ActionController::Base directly (NOT ApplicationController) so it never picks up
  # the org-side acts_as_tenant filter — the Console operates across organizations, explicitly
  # via ActsAsTenant.without_tenant where it needs org data (Story 0.11), not a bypass flag.
  class BaseController < ActionController::Base
    include Pundit::Authorization
    include Auditable
    include Pagy::Method   # pagination helper (Story 0.16)

    allow_browser versions: :modern
    before_action :authenticate_admin!
    before_action :set_english_locale
    layout "console"

    rescue_from Pundit::NotAuthorizedError, with: :not_found

    private

    def not_found
      raise ActionController::RoutingError, "Not Found"
    end

    # Console controllers do not inherit ApplicationController, so they never hit its
    # locale filter. Keep the console in English even when an earlier request left Marathi set.
    def set_english_locale
      I18n.locale = I18n.default_locale
    end

    def deletion_failure_message(record)
      blockers = blocked_dependents(record)
      subject = record.try(:name).presence || "This #{record.class.model_name.human.downcase}"

      if blockers.any?
        "#{subject} can't be deleted while it still has #{blockers.to_sentence}. Remove them first, then try again."
      else
        record.errors.full_messages.to_sentence.presence ||
          "#{subject} can't be deleted because other records still depend on it."
      end
    end

    def blocked_dependents(record)
      record.errors.filter_map do |error|
        name = error.options[:record].to_s.presence
        next unless name && error.type.to_s.start_with?("restrict_dependent_destroy")

        error.type.to_s.end_with?("has_one") ? "a #{name}" : name
      end
    end
  end
end
