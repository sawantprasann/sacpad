# Writes an ActivityLog entry for the current actor (User or Admin). Used for mutations and,
# critically, for Admin cross-org access (Story 0.11).
module Auditable
  extend ActiveSupport::Concern

  private

  def record_activity(action, record: nil, organization: nil)
    actor = current_actor
    return unless actor

    ActivityLog.record!(
      actor: actor,
      action: action,
      record: record,
      organization: organization || (defined?(ActsAsTenant) ? ActsAsTenant.current_tenant : nil)
    )
  end

  def current_actor
    return current_user if respond_to?(:current_user) && current_user
    return current_admin if respond_to?(:current_admin) && current_admin

    nil
  end
end
