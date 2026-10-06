module KitchenCabinet
  # Kitchen Cabinet ticket authorization (Story 1.2). Read gated on module access, write (create)
  # on module write. acts_as_tenant already org-scopes at the model layer; viewer-subtree narrowing
  # for the browse list is Story 1.3's job, so Scope stays permissive here.
  class TicketPolicy < ApplicationPolicy
    def index? = user.role.can_access?("kitchen_cabinet")
    def show?  = index?
    def create? = user.role.can_write?("kitchen_cabinet")
    def new?    = create?

    class Scope < ApplicationPolicy::Scope
      def resolve = scope.all
    end
  end
end
