module Console
  # Published election results for one Assembly or one Lok Sabha.
  # The rows belong to the constituency. Organizations only read them on the dashboard.
  class ConstituencyElectionsController < BaseController
    before_action :set_constituency
    before_action :set_election, only: %i[show edit update destroy]
    before_action :set_parties, only: %i[new create edit update]

    def show
    end

    def new
      @election = @constituency.election_results.new(year: Time.current.year)
      pad_candidate_rows
    end

    def create
      @election = @constituency.election_results.new(election_params)
      if @election.save
        redirect_to helpers.console_election_result_path(@election), notice: "Election result saved."
      else
        pad_candidate_rows
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      pad_candidate_rows
    end

    def update
      if @election.update(election_params)
        redirect_to helpers.console_election_result_path(@election), notice: "Election result updated."
      else
        pad_candidate_rows
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      constituency = @election.constituency
      @election.destroy!
      redirect_to constituency_console_path(constituency), notice: "Election result deleted."
    end

    private

    def set_constituency
      @loksabha = Loksabha.find(params[:loksabha_id])
      if params[:assembly_id].present?
        @assembly = @loksabha.assemblies.find(params[:assembly_id])
        @constituency = @assembly
      else
        @constituency = @loksabha
      end
    end

    def set_election
      @election = @constituency.election_results.includes(:gained_from_party, candidates: :party).find(params[:id])
    end

    def set_parties
      @parties = Party.order(:name)
    end

    def pad_candidate_rows
      blanks = @election.candidates.count { |candidate| candidate.new_record? && candidate.candidate_name.blank? }
      entered = @election.candidates.any? { |candidate| candidate.persisted? || candidate.candidate_name.present? }
      target = entered ? 3 : 6
      (target - blanks).times { @election.candidates.build }
    end

    def election_params
      params.require(:constituency_election).permit(
        :year, :title, :outcome, :gained_from_party_id, :swing,
        :margin_votes, :margin_percent, :margin_change,
        :turnout_votes, :turnout_percent, :turnout_change,
        :valid_votes, :registered_electors, :electors_change,
        candidates_attributes: %i[
          id party_id candidate_name votes vote_percent vote_change
          new_contestant winner position _destroy
        ]
      )
    end

    def constituency_console_path(constituency)
      if constituency.is_a?(Assembly)
        console_loksabha_assembly_path(constituency.loksabha, constituency)
      else
        console_loksabha_path(constituency)
      end
    end
    helper_method :constituency_console_path
  end
end
