module CadreProgram
  # Cadre activity authorization (Story 2.1). Read gated on module access, create on module
  # write. Scope is organization (acts_as_tenant) ∩ viewer subtree ∩ kept.
  class CadreActivityPolicy < ApplicationPolicy
    def index?  = user.role.can_access?("cadre_program")
    def show?   = index? && record.owner_id.in?(user.subtree_user_ids)
    def create? = user.role.can_write?("cadre_program")
    def new?    = create?

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.kept.where(owner_id: user.subtree_user_ids)
      end
    end
  end
end
