module Console
  # Organization lifecycle (Story 0.5/0.6): onboarding wizard, health list, deactivation cascade.
  class OrganizationsController < BaseController
    before_action :set_organization, only: %i[show edit update deactivate reactivate]

    def index
      relation = current_admin.assignable_organizations.includes(:current_party)
      if params[:name].present?
        relation = relation.where("organizations.name ILIKE ?", "%#{Organization.sanitize_sql_like(params[:name].strip)}%")
      end
      if params[:party_id] == "none"
        relation = relation.where(current_party_id: nil)
      elsif params[:party_id].present?
        relation = relation.where(current_party_id: params[:party_id])
      end
      if params[:status] == "active"
        relation = relation.where(active: true)
      elsif params[:status] == "inactive"
        relation = relation.where(active: false)
      end
      @organizations = relation.order(:name, :id)
      @parties = Party.order(:name)
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
      load_users if overview_tab?

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

      load_cadre_activities if params[:tab] == "cadre"
    end

    def edit; end

    def update
      previous_party_id = @organization.current_party_id
      if @organization.update(organization_params)
        @organization.record_party_change!(previous_party_id)
        record_activity("organization.updated", record: @organization, organization: @organization)
        redirect_to console_organization_path(@organization), notice: "Organization updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def deactivate
      @organization.deactivate!
      record_activity("organization.deactivated", record: @organization, organization: @organization)
      redirect_to console_organization_path(@organization), notice: "Organization deactivated — all its users are now locked out."
    end

    def reactivate
      @organization.reactivate!
      record_activity("organization.reactivated", record: @organization, organization: @organization)
      redirect_to console_organization_path(@organization), notice: "Organization reactivated."
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

    def overview_tab?
      params[:tab].blank? || params[:tab] == "overview"
    end

    # Org-wide cadre feed for the console (not the user's subtree). Tenant must be set:
    # cadre activities and their detail rows are organization-scoped.
    def load_cadre_activities
      ActsAsTenant.with_tenant(@organization) do
        relation = CadreProgram::CadreActivity.kept
        if params[:category].present? && CadreProgram::CadreActivity.categories.key?(params[:category])
          relation = relation.where(category: params[:category])
        end
        relation = filter_cadre_activities(relation) if params[:q].present?
        relation = relation.includes(
          :owner, :program, :leadership_meet, :party_program_hosted,
          one_to_one: :karyakarta_user
        ).with_attached_photos.order(created_at: :desc, id: :desc)
        @pagy, @activities = pagy(:offset, relation)
      end
    end

    def filter_cadre_activities(relation)
      term = "%#{CadreProgram::CadreActivity.sanitize_sql_like(params[:q].strip)}%"
      matching = relation
        .left_joins(:program, :leadership_meet, :party_program_hosted, :one_to_one)
        .joins("LEFT OUTER JOIN users cadre_owners ON cadre_owners.id = cadre_activities.owner_id")
        .joins("LEFT OUTER JOIN users cadre_karyakartas ON cadre_karyakartas.id = cadre_activity_one_to_ones.karyakarta_user_id")
        .where(<<~SQL.squish, t: term)
          cadre_activities.impact_notes ILIKE :t
          OR cadre_owners.name ILIKE :t
          OR cadre_activity_programs.program_name ILIKE :t
          OR cadre_activity_leadership_meets.whom_to_meet ILIKE :t
          OR cadre_activity_party_program_hosteds.program_name ILIKE :t
          OR cadre_activity_one_to_ones.karyakarta_name_text ILIKE :t
          OR cadre_karyakartas.name ILIKE :t
        SQL
        .select("cadre_activities.id")
      relation.where(id: matching)
    end

    def load_users
      @user_roles = Role.where(id: @organization.users.select(:role_id)).order(:name)
      users = @organization.users.includes(:role, :parent)
      if params[:user_q].present?
        term = "%#{User.sanitize_sql_like(params[:user_q].strip)}%"
        users = users.where("users.name ILIKE :t OR users.email ILIKE :t", t: term)
      end
      users = users.where(role_id: params[:role_id]) if params[:role_id].present?
      if params[:user_status] == "active"
        users = users.where(active: true)
      elsif params[:user_status] == "inactive"
        users = users.where(active: false)
      end
      @users = users.order(:name, :id)
    end

    def organization_params
      permitted = params.require(:organization).permit(:name, :constituency_type, :constituency_id, :current_party_id)
      permitted[:constituency_type] = nil if permitted[:constituency_type].blank?
      permitted[:constituency_id] = nil if permitted[:constituency_id].blank?
      permitted[:current_party_id] = nil if permitted[:current_party_id].blank?
      permitted
    end
  end
end
