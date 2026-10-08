module Console
  # Global Voter list admin (Story 0.15 v2). Voters are global, shared across orgs.
  # Display with search by voter_id or name, pagination. No edit (immutable once uploaded).
  class VotersController < BaseController
    before_action :set_voter, only: [:show]

    def index
      relation = Voter.all
      relation = relation.where("voter_id ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      @pagy, @voters = pagy(:offset, relation.order(:voter_id))
    end

    def show
      # Load org-scoped sentiments without tenant context (console operates cross-org)
      @voter_sentiments = ActsAsTenant.without_tenant { @voter.voter_sentiments.includes(:organization) }
    end

    private

    def set_voter
      @voter = Voter.find(params[:id])
    end
  end
end
