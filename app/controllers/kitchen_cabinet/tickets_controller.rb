module KitchenCabinet
  # Story 1.1 stub: the target of the sidebar category links. It only resolves the selected
  # category from the `?category=` slug and renders an empty-state placeholder. The real scoped,
  # paginated ticket list (card list on mobile, filterable table on desktop) is Story 1.3, and the
  # Ticket model + capture flow is Story 1.2.
  class TicketsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_kitchen_cabinet_access

    # Scoped, filtered, paginated browse list (Story 1.3). policy_scope narrows to
    # organization (acts_as_tenant) ∩ viewer subtree ∩ kept; "Get All Details" returns this
    # paginated relation, never an unpaged dump (NFR12). Pagination via pagy 43.x (Pagy::Method).
    def index
      @category = TicketCategory.active.find_by(slug: params[:category])

      relation = policy_scope(KitchenCabinet::Ticket).includes(:ticket_category, :owner)
      relation = relation.where(ticket_category_id: @category.id) if @category
      if params[:status].present? && KitchenCabinet::Ticket.statuses.key?(params[:status])
        relation = relation.where(status: params[:status])
      end
      if params[:q].present?
        term = "%#{params[:q].strip}%"
        relation = relation.where("person_name ILIKE :t OR village ILIKE :t", t: term)
      end
      relation = relation.order(reported_at: :desc, id: :desc)

      respond_to do |format|
        format.html { @pagy, @tickets = pagy(:offset, relation) }
        format.xlsx do
          # Export the full scoped+filtered set (unpaginated), scoped to the viewer (Story 1.8, FR49).
          @tickets = relation
          response.headers["Content-Disposition"] = "attachment; filename=kitchen_cabinet_tickets.xlsx"
        end
      end
    end

    # Ticket detail (Story 1.3). policy_scope guarantees org ∩ subtree ∩ kept; a ticket outside
    # the viewer's scope raises RecordNotFound → 404 (never 403). authorize is belt-and-suspenders.
    def show
      @ticket = policy_scope(KitchenCabinet::Ticket).find(params[:id])
      authorize @ticket
    end

    # Status transition (Story 1.4). The model guard + policy are the authority; the view only
    # offers legal buttons. An illegal `to_status` is refused with a flash, no row written.
    def status
      @ticket = policy_scope(KitchenCabinet::Ticket).find(params[:id])
      authorize @ticket, :update?
      to = params[:to_status]
      if @ticket.may_change_to?(to)
        @ticket.change_status!(to: to, actor: current_user)
        redirect_to kitchen_cabinet_ticket_path(@ticket), notice: "Status updated to #{to.to_s.humanize}."
      else
        redirect_to kitchen_cabinet_ticket_path(@ticket),
                    alert: "Can't move from #{@ticket.status.humanize} to #{to.to_s.humanize}."
      end
    end

    # Mobile-first capture (Story 1.2): pre-fill to the category tapped in the sidebar.
    def new
      @ticket = Ticket.new(ticket_category: TicketCategory.active.find_by(slug: params[:category]))
      authorize @ticket
    end

    def create
      @ticket = Ticket.new(ticket_params)
      @ticket.owner = current_user          # organization is set by acts_as_tenant, never from params
      authorize @ticket
      if @ticket.save
        redirect_to kitchen_cabinet_tickets_path(category: @ticket.ticket_category&.slug),
                    notice: "Ticket ##{@ticket.ticket_number} logged."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # Attach/update the voter id on a resolved ticket (Story 1.6). The model validation is the
    # authority — setting voter_id on an unresolved ticket simply fails to persist.
    def voter
      @ticket = policy_scope(KitchenCabinet::Ticket).find(params[:id])
      authorize @ticket, :update?
      if @ticket.update(voter_id: params[:voter_id])
        redirect_to kitchen_cabinet_ticket_path(@ticket), notice: "Voter ID saved."
      else
        redirect_to kitchen_cabinet_ticket_path(@ticket), alert: @ticket.errors.full_messages.to_sentence
      end
    end

    private

    def ticket_params
      params.require(:ticket).permit(:person_name, :village, :mobile, :description,
        :reported_at, :nature_of_issue, :reported_value, :ticket_category_id, attachments: [])
    end

    # Nav visibility is gated in the sidebar, but access is also enforced here (not UI-only):
    # a user whose role has no Kitchen Cabinet access cannot reach the module even by URL.
    def require_kitchen_cabinet_access
      redirect_to root_path, alert: "You don't have access to Kitchen Cabinet." unless
        current_user.role.can_access?("kitchen_cabinet")
    end
  end
end
