module Console
  # Per-org Politician roster (§6.3a, Story 0.12) — Admin-managed, nested under an organization.
  # Wraps actions in the target org's tenant context so Politician (OrganizationScoped) auto-scopes.
  class PoliticiansController < BaseController
    before_action :set_organization
    around_action :scope_to_org
    before_action :set_politician, only: %i[edit update destroy]

    def index
      @politicians = Politician.kept.order(:id)
    end

    def new
      @politician = Politician.new
    end

    def create
      @politician = Politician.new(politician_params)
      if @politician.save
        redirect_to console_organization_politicians_path(@organization), notice: "Politician added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @politician.update(politician_params)
        redirect_to console_organization_politicians_path(@organization), notice: "Politician updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @politician.discard_by(current_admin)
      redirect_to console_organization_politicians_path(@organization), notice: "Politician retired."
    end

    private

    def set_organization
      @organization = current_admin.assignable_organizations.find(params[:organization_id])
    end

    def scope_to_org(&block)
      ActsAsTenant.with_tenant(@organization, &block)
    end

    def set_politician
      @politician = Politician.find(params[:id])
    end

    def politician_params
      params.require(:politician).permit(:name, :party_id, :is_own_politician)
    end
  end
end
