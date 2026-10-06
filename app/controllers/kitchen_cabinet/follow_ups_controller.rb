module KitchenCabinet
  # Append a follow-up note to a ticket (Story 1.5). Nested under tickets. Any KC-write user whose
  # subtree includes the ticket may add one — no extra capability (AC 2); reuses the ticket's
  # `update?` policy. Out-of-subtree/other-org → 404 (policy_scope); read-only → 404 (Pundit).
  class FollowUpsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_kitchen_cabinet_access

    def create
      @ticket = policy_scope(KitchenCabinet::Ticket).find(params[:ticket_id])
      authorize @ticket, :update?
      follow_up = @ticket.follow_ups.new(follow_up_params)
      follow_up.created_by = current_user
      if follow_up.save
        redirect_to kitchen_cabinet_ticket_path(@ticket), notice: "Follow-up added."
      else
        redirect_to kitchen_cabinet_ticket_path(@ticket), alert: follow_up.errors.full_messages.to_sentence
      end
    end

    private

    def require_kitchen_cabinet_access
      redirect_to root_path, alert: "You don't have access to Kitchen Cabinet." unless
        current_user.role.can_access?("kitchen_cabinet")
    end

    def follow_up_params
      params.require(:ticket_follow_up).permit(:note, :attachment)
    end
  end
end
