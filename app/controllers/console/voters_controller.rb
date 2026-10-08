module Console
  # Global Voter list admin (Story 0.15 v2). Voters are global, shared across orgs.
  # Display with search by voter_id or name, pagination. No edit (immutable once uploaded).
  class VotersController < BaseController
    before_action :set_voter, only: [:show]

    def index
      @voters = Voter.all
      @voters = @voters.where("voter_id ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      @voters, @pagy = pagy(@voters.order(:voter_id), items: 50)
    end

    def show
    end

    private

    def set_voter
      @voter = Voter.find(params[:id])
    end
  end
end
