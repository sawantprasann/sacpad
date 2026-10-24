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
      @categories = TicketCategory.active.order(:display_order, :name)
      @category = @categories.find_by(slug: params[:category])
      @villages = Village.order(:name)
      assign_reported_on_bounds
      relation = filtered_tickets

      respond_to do |format|
        format.html do
          @charts = chart_series(relation)
          @pagy, @tickets = pagy(:offset, relation)
        end
        format.xlsx do
          # Export the full scoped+filtered set (unpaginated), scoped to the viewer (Story 1.8, FR49).
          @tickets = relation
          response.headers["Content-Disposition"] = "attachment; filename=beneficiaries.xlsx"
        end
      end
    end

    # Ticket detail (Story 1.3). policy_scope guarantees org ∩ subtree ∩ kept; a ticket outside
    # the viewer's scope raises RecordNotFound → 404 (never 403). authorize is belt-and-suspenders.
    def show
      @ticket = policy_scope(KitchenCabinet::Ticket).find(params[:id])
      authorize @ticket
      @voter_matches = @ticket.voter_id.blank? ? KitchenCabinet::VoterMatch.for_ticket(@ticket) : []
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

    # Category is chosen on the form. A ?category= slug still pre-selects that option.
    def new
      @ticket = Ticket.new(ticket_category: TicketCategory.active.find_by(slug: params[:category]))
      @categories = TicketCategory.active.order(:display_order, :name)
      authorize @ticket
    end

    def create
      @ticket = Ticket.new(ticket_params)
      @ticket.owner = current_user          # organization is set by acts_as_tenant, never from params
      authorize @ticket
      if @ticket.save
        redirect_after_create
      else
        @categories = TicketCategory.active.order(:display_order, :name)
        render :new, status: :unprocessable_entity
      end
    end

    # Edit ticket (org admins can edit any ticket; team leads see read-only).
    def edit
      @ticket = policy_scope(KitchenCabinet::Ticket).find(params[:id])
      authorize @ticket, :edit?
    end

    # Update ticket (org admins can update any ticket in their org).
    def update
      @ticket = policy_scope(KitchenCabinet::Ticket).find(params[:id])
      authorize @ticket, :update?
      if @ticket.update(ticket_params)
        redirect_to kitchen_cabinet_ticket_path(@ticket), notice: "Ticket updated."
      else
        render :edit, status: :unprocessable_entity
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

    # Representative picks one voter when several people in the village share the exact name.
    def match_voter
      @ticket = policy_scope(KitchenCabinet::Ticket).find(params[:id])
      authorize @ticket, :update?
      voter = Voter.find_by(id: params[:matched_voter_id])
      matches = KitchenCabinet::VoterMatch.for_ticket(@ticket)
      if @ticket.voter_id.present? || voter.nil? || matches.none? { |row| row.id == voter.id }
        redirect_to kitchen_cabinet_ticket_path(@ticket), alert: "Choose one of the matched voters."
        return
      end

      @ticket.link_matched_voter!(voter, by: current_user)
      redirect_to kitchen_cabinet_ticket_path(@ticket),
                  notice: "Linked #{voter.name}. Sentiment set to transit. You'll confirm how they feel when this is closed."
    end

    private

    def ticket_params
      params.require(:ticket).permit(:person_name, :representative_name, :village, :mobile, :description,
        :reported_at, :nature_of_issue, :reported_value, :ticket_category_id, attachments: [])
    end

    def filtered_tickets
      relation = policy_scope(KitchenCabinet::Ticket).includes(:ticket_category, :owner)
      relation = relation.where(ticket_category_id: @category.id) if @category
      if params[:status].present? && KitchenCabinet::Ticket.statuses.key?(params[:status])
        relation = relation.where(status: params[:status])
      end
      if params[:name].present?
        relation = relation.where("tickets.person_name ILIKE ?", like_term(params[:name]))
      end
      if params[:village].present?
        relation = relation.where(village: params[:village])
      end
      if params[:reporter].present?
        relation = relation.joins(:owner).where("users.name ILIKE ?", like_term(params[:reporter]))
      end
      if params[:q].present?
        term = like_term(params[:q])
        relation = relation.where("tickets.person_name ILIKE :t OR tickets.village ILIKE :t", t: term)
      end
      relation = relation.where(reported_at: @from_date..) if @from_date
      relation = relation.where(reported_at: ..@to_date) if @to_date
      relation.order(reported_at: :desc, id: :desc)
    end

    # First visit (no date params) selects the last 30 days. A submitted blank date drops that bound.
    def assign_reported_on_bounds
      if params.key?(:from_date) || params.key?(:to_date)
        @from_date = parse_filter_date(params[:from_date])
        @to_date = parse_filter_date(params[:to_date])
      else
        @from_date = Date.current - 30
        @to_date = Date.current
      end
    end

    def parse_filter_date(value)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def beneficiaries_by_date_and_category(relation)
      grouped = relation.joins(:ticket_category)
                        .group("tickets.reported_at", "ticket_categories.name")
                        .count
      return [] if grouped.empty?

      dates = grouped.keys.map(&:first).uniq.sort_by(&:to_date)
      categories = grouped.keys.map(&:last).uniq.sort
      categories.map do |category|
        data = dates.to_h do |date|
          [ date.to_date.strftime("%d %b %Y"), grouped.fetch([ date, category ], 0) ]
        end
        { name: category, data: data }
      end
    end

    def chart_series(relation)
      base = relation.unscope(:order)
      status_counts = base.group("tickets.status").count
      pie = KitchenCabinet::Ticket.statuses.each_with_object({}) do |(name, value), series|
        count = status_counts[name] || status_counts[value] || status_counts[value.to_s] || 0
        series[name.humanize] = count if count.positive?
      end

      {
        line: base.group("tickets.reported_at").order("tickets.reported_at").count,
        bar: beneficiaries_by_date_and_category(base),
        pie: pie,
        pie_by_category: base.joins(:ticket_category).group("ticket_categories.name").order("ticket_categories.name").count
      }
    end

    def redirect_after_create
      list = kitchen_cabinet_tickets_path(category: @ticket.ticket_category&.slug)
      matches = KitchenCabinet::VoterMatch.for_ticket(@ticket)
      if matches.one?
        @ticket.link_matched_voter!(matches.first, by: current_user)
        redirect_to list, notice: "Ticket ##{@ticket.ticket_number} logged. Matched #{matches.first.name} and set sentiment to transit."
      elsif matches.many?
        redirect_to kitchen_cabinet_ticket_path(@ticket),
                    notice: "Ticket logged. Several voters in this village share this name — select the right one."
      else
        redirect_to list, notice: "Ticket ##{@ticket.ticket_number} logged."
      end
    end

    def like_term(value)
      "%#{KitchenCabinet::Ticket.sanitize_sql_like(value.to_s.strip)}%"
    end

    # Nav visibility is gated in the sidebar, but access is also enforced here (not UI-only):
    # a user whose role has no Beneficiaries access cannot reach the module even by URL.
    def require_kitchen_cabinet_access
      redirect_to root_path, alert: "You don't have access to Beneficiaries." unless
        current_user.role.can_access?("kitchen_cabinet")
    end
  end
end
