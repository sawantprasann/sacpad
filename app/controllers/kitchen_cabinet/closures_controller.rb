module KitchenCabinet
  # Two-step closure + voter-sentiment capture (Story 1.7). Composes the status→closed transition
  # (Story 1.4), the voter_id gate (Story 1.6) and the Voter sentiment write (Story 0.15). The
  # voter and sentiment are optional; a missing/unmatched voter still closes the ticket.
  class ClosuresController < ApplicationController
    before_action :authenticate_user!
    before_action :require_kitchen_cabinet_access
    before_action :set_ticket

    def new; end

    def create
      ActiveRecord::Base.transaction do
        @ticket.change_status!(to: "closed", actor: current_user)   # Tier-2 log + closed_at
        @ticket.update!(closed_at: Date.parse(params[:closure_date])) if params[:closure_date].present?

        if params[:voter_id].present?
          @ticket.update!(voter_id: params[:voter_id])              # gate passes now that it's closed
          sentiment = params[:sentiment].to_s
          if Voter.sentiment_statuses.key?(sentiment) && (voter = @ticket.matched_voter)
            voter.record_sentiment!(sentiment, by: current_user)
          end
        end
      end
      redirect_to kitchen_cabinet_ticket_path(@ticket), notice: "On record as help delivered."
    rescue Date::Error
      redirect_to kitchen_cabinet_ticket_path(@ticket), alert: "Enter a valid closure date."
    end

    private

    def set_ticket
      @ticket = policy_scope(KitchenCabinet::Ticket).find(params[:ticket_id])
      authorize @ticket, :update?
      return if @ticket.may_change_to?("closed")

      redirect_to kitchen_cabinet_ticket_path(@ticket),
                  alert: "Move the ticket to In progress before closing."
    end

    def require_kitchen_cabinet_access
      redirect_to root_path, alert: "You don't have access to Kitchen Cabinet." unless
        current_user.role.can_access?("kitchen_cabinet")
    end
  end
end
