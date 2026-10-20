module Console
  # Global Voter list admin (Story 0.15 v2). Voters are global, shared across orgs.
  # Filter by voter ID, village, booth, and name. Admins can correct a row from the list.
  class VotersController < BaseController
    before_action :set_voter, only: %i[show edit update]
    helper_method :voter_filters

    def index
      @villages = Village.order(:name)
      relation = Voter.includes(:booth, :village).order(created_at: :desc)
      relation = relation.where(voter_id: params[:voter_id].strip) if params[:voter_id].present?
      relation = filter_by_sr_no(relation)
      relation = relation.where(village_id: params[:village_id]) if params[:village_id].present?
      if params[:booth].present?
        relation = relation.joins(:booth).where(booths: { number: params[:booth].strip })
      end
      relation = filter_by_name(relation) if params[:name].present?
      @pagy, @voters = pagy(:offset, relation)
      @coverage = Voter.coverage
      @search_hint = "Showing recently added voters." if voter_filters.values.all?(&:blank?)
    end

    def show
      # Load org-scoped sentiments without tenant context (console operates cross-org)
      @voter_sentiments = ActsAsTenant.without_tenant { @voter.voter_sentiments.includes(:organization) }
    end

    def edit
      load_booth_options
    end

    def update
      @voter.assign_attributes(voter_params)
      copy_geography_from_booth
      if save_voter
        redirect_to console_voter_path(@voter), notice: "Voter updated."
      else
        load_booth_options
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_voter
      @voter = Voter.includes(:booth, :state, :loksabha, :assembly, :village).find(params[:id])
    end

    def voter_filters
      params.permit(:voter_id, :sr_no, :name, :village_id, :booth).to_h
    end

    def voter_params
      params.require(:voter).permit(
        :voter_id, :first_name, :middle_name, :last_name, :mobile,
        :age, :gender, :house_no, :sr_no, :booth_id
      )
    end

    def load_booth_options
      @booth_options = Booth.includes(:village).by_number.map do |booth|
        [ "Booth #{booth.number} · #{booth.village.name}", booth.id ]
      end
    end

    # The booth owns the roll's place. Keep state, constituency, and village in step with it.
    def copy_geography_from_booth
      booth = @voter.booth
      if booth.nil?
        @voter.village = @voter.assembly = @voter.loksabha = @voter.state = nil
        return
      end

      village = booth.village
      assembly = village.assembly
      loksabha = assembly.loksabha
      @voter.village = village
      @voter.assembly = assembly
      @voter.loksabha = loksabha
      @voter.state = loksabha.state
    end

    def save_voter
      @voter.save
    rescue ActiveRecord::RecordNotUnique
      @voter.errors.add(:voter_id, "has already been taken")
      false
    end

    def filter_by_sr_no(relation)
      return relation if params[:sr_no].blank?

      sr_no = Integer(params[:sr_no], exception: false)
      sr_no ? relation.where(sr_no: sr_no) : relation.none
    end

    def filter_by_name(relation)
      unless params[:village_id].present? || params[:booth].present? || params[:voter_id].present? || params[:sr_no].present?
        @search_hint = "Add a village, booth, voter ID, or Sr no to search by name."
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
