module Console
  # Global Voter list admin (Story 0.15 v2). Voters are global, shared across orgs.
  # Filter by voter ID, village, booth, and name. No edit (immutable once uploaded).
  class VotersController < BaseController
    before_action :set_voter, only: [ :show ]
    helper_method :voter_filters

    def index
      relation = Voter.includes(:booth, :village).order(created_at: :desc)
      relation = relation.where(voter_id: params[:voter_id].strip) if params[:voter_id].present?
      if params[:village].present?
        relation = relation.joins(:village).where("villages.name ILIKE ?", "%#{like(params[:village])}%")
      end
      if params[:booth].present?
        relation = relation.joins(:booth).where(booths: { number: params[:booth].strip })
      end
      relation = filter_by_name(relation) if params[:name].present?
      @pagy, @voters = pagy(:offset, relation)
      @search_hint = "Showing recently added voters." if voter_filters.values.all?(&:blank?)
    end

    def show
      # Load org-scoped sentiments without tenant context (console operates cross-org)
      @voter_sentiments = ActsAsTenant.without_tenant { @voter.voter_sentiments.includes(:organization) }
    end

    private

    def set_voter
      @voter = Voter.includes(:booth, :state, :loksabha, :assembly, :village).find(params[:id])
    end

    def voter_filters
      params.permit(:voter_id, :name, :village, :booth).to_h
    end

    def like(value)
      ActiveRecord::Base.sanitize_sql_like(value.strip)
    end

    def filter_by_name(relation)
      unless params[:village].present? || params[:booth].present? || params[:voter_id].present?
        @search_hint = "Add a village, booth, or voter ID to search by name."
        return relation
      end

      term = params[:name].strip.downcase
      ids = relation.filter_map { |voter| voter.id if voter_name(voter).include?(term) }
      Voter.includes(:booth, :village).where(id: ids).order(created_at: :desc)
    end

    def voter_name(voter)
      [ voter.first_name, voter.middle_name, voter.last_name ].compact.join(" ").downcase
    end
  end
end
