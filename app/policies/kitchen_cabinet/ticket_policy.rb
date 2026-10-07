module KitchenCabinet
  # Kitchen Cabinet ticket authorization (Story 1.2). Read gated on module access, write (create)
  # on module write. acts_as_tenant already org-scopes at the model layer; viewer-subtree narrowing
  # for the browse list is Story 1.3's job, so Scope stays permissive here.
  # Org admins can edit/update any ticket in their org; team leads can only edit their subtree.
  class TicketPolicy < ApplicationPolicy
    def index? = user.role.can_access?("kitchen_cabinet")
    def show?  = index? && record.owner_id.in?(user.subtree_user_ids)
    def create? = user.role.can_write?("kitchen_cabinet")
    def new?    = create?
    # Status change (Story 1.4): write permission + the ticket is in the viewer's subtree.
    def update? = user.role.can_write?("kitchen_cabinet") && (org_admin? || record.owner_id.in?(user.subtree_user_ids))
    def edit?   = update?

    # Browse list (Story 1.3): organization is already enforced by acts_as_tenant; here we add the
    # viewer-subtree narrowing (owner ∈ viewer subtree, Story 0.9) and exclude soft-deleted rows.
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.kept.where(owner_id: user.subtree_user_ids)
      end
    end

    private

    def org_admin?
      user.role.slug == "org_admin"
    end
  end
end
