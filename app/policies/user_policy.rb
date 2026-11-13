class UserPolicy < ApplicationPolicy
  def index? = true
  def show?  = in_scope?
  def create? = acting_user_can_create?
  def new?    = create?
  def update? = manageable?
  def deactivate? = manageable? && record.active?
  def reactivate? = manageable? && !record.active?
  def resend_invitation? = manageable? && record.pending_invitation?
  def send_password_reset? = manageable? && !record.pending_invitation?

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

  # Team actions apply to someone else in this admin's subtree. An admin cannot
  # deactivate or reset their own account from this screen.
  def manageable?
    acting_user_can_create? && in_scope? && record.id != user.id
  end

  def in_scope?
    record.organization_id == user.organization_id && user.subtree_user_ids.include?(record.id)
  end
end
