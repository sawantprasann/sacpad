module GroundReports
  # Village report authorization (Story 3.1). Read gated on module access, create on module
  # write. Scope is organization (acts_as_tenant) ∩ viewer subtree ∩ kept.
  class GroundReportPolicy < ApplicationPolicy
    def index?  = user.role.can_access?("ground_reports")
    def show?   = index? && record.owner_id.in?(user.subtree_user_ids)
    def create? = user.role.can_write?("ground_reports")
    def new?    = create?

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.kept.where(owner_id: user.subtree_user_ids)
      end
    end
  end
end
