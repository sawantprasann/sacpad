module KitchenCabinet
  # Story 1.1 stub: the target of the sidebar category links. It only resolves the selected
  # category from the `?category=` slug and renders an empty-state placeholder. The real scoped,
  # paginated ticket list (card list on mobile, filterable table on desktop) is Story 1.3, and the
  # Ticket model + capture flow is Story 1.2.
  class TicketsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_kitchen_cabinet_access

    def index
      @category = TicketCategory.active.find_by(slug: params[:category])
    end

    private

    # Nav visibility is gated in the sidebar, but access is also enforced here (not UI-only):
    # a user whose role has no Kitchen Cabinet access cannot reach the module even by URL.
    def require_kitchen_cabinet_access
      redirect_to root_path, alert: "You don't have access to Kitchen Cabinet." unless
        current_user.role.can_access?("kitchen_cabinet")
    end
  end
end
