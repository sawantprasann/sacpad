module Console
  # Org admin ticket management (Story 0.16 enhancement: full CRUD for oversight).
  # Handles org-wide ticket operations: view, edit, delete. Scoped to org (not subtree).
  class OrgTicketsController < BaseController
    before_action :set_organization
    before_action :set_ticket, only: %i[show edit update destroy]

    def show
      @ticket = ActsAsTenant.with_tenant(@organization) do
        KitchenCabinet::Ticket.kept.find(params[:id])
      end
    end

    def edit
      @ticket = ActsAsTenant.with_tenant(@organization) do
        KitchenCabinet::Ticket.kept.find(params[:id])
      end
    end

    def update
      if @ticket.update(ticket_params)
        redirect_to console_organization_path(@organization, tab: "kitchen_cabinet"),
                    notice: "Ticket updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @ticket.discard
      redirect_to console_organization_path(@organization, tab: "kitchen_cabinet"),
                  notice: "Ticket deleted."
    end

    private

    def set_organization
      @organization = current_admin.assignable_organizations.find(params[:organization_id])
    end

    def set_ticket
      @ticket = ActsAsTenant.with_tenant(@organization) do
        KitchenCabinet::Ticket.kept.find(params[:id])
      end
    end

    def ticket_params
      params.require(:ticket).permit(:person_name, :village, :mobile, :description,
                                      :reported_at, :nature_of_issue, :reported_value,
                                      :ticket_category_id, :status)
    end
  end
end
