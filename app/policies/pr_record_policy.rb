class PrRecordPolicy < ApplicationPolicy
  def index? = user.role.can_access?("pr")
  def show?  = index? && (org_admin? || record.owner_id.in?(user.subtree_user_ids))
  def create? = user.role.can_write?("pr")
  def new?    = create?
  def edit?   = user.role.can_write?("pr") && (org_admin? || record.owner_id.in?(user.subtree_user_ids))
  def update? = edit?

  # Browse list: organization scoped (acts_as_tenant), viewer subtree narrowing, exclude soft-deleted rows.
  # Org admins see all records in org; regular users see only their subtree.
  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.kept
      if user.role.slug == "org_admin"
        base
      else
        base.where(owner_id: user.subtree_user_ids)
      end
    end
  end

  private

  def org_admin?
    user.role.slug == "org_admin"
  end
end
