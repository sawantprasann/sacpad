module Console
  # Organization lifecycle (Story 0.5/0.6): onboarding wizard, health list, deactivation cascade.
  class OrganizationsController < BaseController
    before_action :set_organization, only: %i[show deactivate reactivate]

    def index
      @organizations = current_admin.assignable_organizations.order(:id)
    end

    def new
      @organization = Organization.new
    end

    def create
      result = onboard
      if result[:ok]
        redirect_to console_organizations_path, notice: "Organization onboarded."
      else
        @organization = result[:organization]
        flash.now[:alert] = result[:error]
        render :new, status: :unprocessable_entity
      end
    end

    # Viewing a specific org's data is logged and visibly flagged (§8a, Story 0.11).
    # Story 0.16: Kitchen Cabinet / Cadre tabs load org-wide ticket/activity data (org admin view).
    def show
      record_activity("organization.viewed", record: @organization, organization: @organization)
      @viewing_org = @organization

      # Load Kitchen Cabinet tickets if tab is selected (Story 0.16, AC 1).
      if params[:tab] == "kitchen_cabinet"
        ActsAsTenant.with_tenant(@organization) do
          relation = KitchenCabinet::Ticket.kept.includes(:ticket_category, :owner)
          if params[:category]
            cat = TicketCategory.active.find_by(slug: params[:category])
            relation = relation.where(ticket_category_id: cat.id) if cat
          end
          if params[:status].present? && KitchenCabinet::Ticket.statuses.key?(params[:status])
            relation = relation.where(status: params[:status])
          end
          if params[:q].present?
            term = "%#{params[:q].strip}%"
            relation = relation.where("person_name ILIKE :t OR village ILIKE :t", t: term)
          end
          relation = relation.order(reported_at: :desc, id: :desc)
          @pagy, @tickets = pagy(:offset, relation)
        end
      end
    end

    def deactivate
      @organization.deactivate!
      redirect_to console_organizations_path, notice: "Organization deactivated — all its users are now locked out."
    end

    def reactivate
      @organization.reactivate!
      redirect_to console_organizations_path, notice: "Organization reactivated."
    end

    private

    def set_organization
      @organization = current_admin.assignable_organizations.find(params[:id])
    end

    # Wizard: org + constituency + (optional) party + REQUIRED initial Org Admin, in one transaction.
    def onboard
      org = Organization.new(organization_params)
      admin = params.fetch(:org_admin, {}).permit(:name, :email, :password)
      if admin[:email].blank? || admin[:password].blank?
        return { ok: false, organization: org, error: "An initial Org Admin (email + password) is required." }
      end

      ActsAsTenant.without_tenant do
        ActiveRecord::Base.transaction do
          org.save!
          if org.current_party_id
            org.party_memberships.create!(party_id: org.current_party_id, started_at: Time.current)
          end
          role = Role.find_by!(slug: "org_admin")
          org.users.create!(role: role, name: admin[:name].presence || "Org Admin",
                            email: admin[:email], password: admin[:password])
        end
      end
      { ok: true }
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, organization: org, error: e.message }
    end

    def organization_params
      params.require(:organization).permit(:name, :constituency_type, :constituency_id, :current_party_id)
    end
  end
end
