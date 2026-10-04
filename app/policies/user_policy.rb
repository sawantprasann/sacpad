class UserPolicy < ApplicationPolicy
  def index? = true
  def show?  = in_scope?
  def create? = acting_user_can_create?
  def new?    = create?
  def update? = acting_user_can_create? && in_scope?

  # Only roles with can_create_users may create users (default: org_admin only, §3.3/§3.5).
  # Narrowed subtree scoping is enforced here + in Scope.
  class Scope < Scope
    def resolve
      scope.where(organization_id: user.organization_id, id: user.subtree_user_ids)
    end
  end

  private

  def acting_user_can_create?
    user.role.can_create_users?
  end

  def in_scope?
    record.organization_id == user.organization_id && user.subtree_user_ids.include?(record.id)
  end
end
