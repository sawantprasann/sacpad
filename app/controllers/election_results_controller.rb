class ElectionResultsController < ApplicationController
  before_action :authenticate_user!

  def show
    @constituency_elections = ConstituencyElection.for_organization(current_user.organization).to_a
    requested = params[:election_year].to_s.to_i
    @constituency_election = @constituency_elections.detect { |election| election.year == requested }
    @constituency_election ||= @constituency_elections.first
  end
end
