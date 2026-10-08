module Console
  # Global Voter list admin (Story 0.15 v2). Voters are global, shared across orgs.
  # Display with search by voter_id or name, pagination. No edit (immutable once uploaded).
  class VotersController < BaseController
    before_action :set_voter, only: [:show]

    def index
      if params[:q].present? && params[:q].length >= 3
        # Search by voter_id (deterministic encrypted, indexed for fast lookup)
        relation = Voter.where("voter_id ILIKE ?", "%#{params[:q]}%")
        @pagy, @voters = pagy(:offset, relation.order(:voter_id))
      else
        # Default: show recent voters (much faster than Voter.all for large datasets)
        relation = Voter.order(created_at: :desc)
        @pagy, @voters = pagy(:offset, relation)
        @search_hint = "Search requires at least 3 characters" if params[:q].present?
      end
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
