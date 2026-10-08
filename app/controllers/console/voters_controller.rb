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
    end

    private

    def set_voter
      @voter = Voter.find(params[:id])
    end
  end
end
