# Org-side voter management. Sentiment and voted are stored per organization.
class VotersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_voter_access
  before_action :require_voter_write, only: %i[update_sentiment update_voted]
  before_action :set_voter, only: %i[show update_sentiment update_voted]
  helper_method :voter_filters

  def index
    @election = Election.ensure_current!(current_organization)
    relation = filtered_voters
    respond_to do |format|
      format.html do
        @pagy, @voters = pagy(:offset, relation)
        load_roll_state(@voters)
      end
      format.xlsx do
        @voters = relation
        load_roll_state(@voters)
        response.headers["Content-Disposition"] = "attachment; filename=voters.xlsx"
      end
    end
    @villages = current_organization.villages.order(:name)
    @booth_numbers = Booth.where(village_id: @villages.select(:id)).by_number.pluck(:number).uniq
  end

  def show
    @election = Election.ensure_current!(current_organization)
    @voter_sentiment = sentiment_for(@voter)
    @turnout = VoterTurnout.find_by(election: @election, voter: @voter)
  end

  def update_sentiment
    sentiment = sentiment_for(@voter)
    if sentiment.update(
      sentiment_status: params[:sentiment_status],
      sentiment_updated_by_id: current_user.id,
      sentiment_updated_at: Time.current
    )
      redirect_to voter_path(@voter), notice: "Sentiment updated."
    else
      redirect_to voter_path(@voter), alert: "Failed to update sentiment."
    end
  end

  def update_voted
    election = Election.ensure_current!(current_organization)
    voted = ActiveModel::Type::Boolean.new.cast(params[:voted])
    VoterTurnout.mark!(election: election, voter: @voter, voted: voted, by: current_user)
    redirect_back fallback_location: voters_path(voter_filters),
                  notice: voted ? "Marked as voted for #{election.name}." : "Marked as not voted for #{election.name}."
  end

  private

  def set_voter
    @voter = Voter.find(params[:id])
  end

  def filtered_voters
    relation = Voter.all
    relation = relation.where(voter_id: params[:voter_id].strip) if params[:voter_id].present?
    relation = relation.where(sr_no: params[:sr_no]) if params[:sr_no].present?
    relation = relation.where(village_id: params[:village_id]) if params[:village_id].present?
    if params[:booth].present?
      relation = relation.joins(:booth).where(booths: { number: params[:booth].strip })
    end
    if params[:sentiment].present?
      ids = VoterSentiment.where(sentiment_status: params[:sentiment]).select(:voter_id)
      relation = relation.where(id: ids)
    end
    if params[:voted] == "yes"
      relation = relation.where(id: VoterTurnout.where(election: @election, voted: true).select(:voter_id))
    elsif params[:voted] == "no"
      voted_ids = VoterTurnout.where(election: @election, voted: true).select(:voter_id)
      relation = relation.where.not(id: voted_ids)
    end
    if params[:name].present?
      term = params[:name].strip.downcase
      matched = relation.filter_map do |voter|
        voter.id if voter_name(voter).downcase.include?(term)
      end
      relation = Voter.where(id: matched)
    end
    relation.includes(:booth, :village).order(Arel.sql("sr_no ASC NULLS LAST"), :id)
  end

  def voter_name(voter)
    [ voter.first_name, voter.middle_name, voter.last_name ].compact.join(" ")
  rescue ActiveRecord::Encryption::Errors::Decryption
    ""
  end

  def load_roll_state(voters)
    ids = voters.map(&:id)
    @sentiments = VoterSentiment.where(voter_id: ids).index_by(&:voter_id)
    @turnouts = VoterTurnout.where(election: @election, voter_id: ids).index_by(&:voter_id)
  end

  def sentiment_for(voter)
    VoterSentiment.find_or_create_by!(voter_id: voter.id)
  end

  def voter_filters
    filters = params.permit(:voter_id, :name, :booth, :village_id, :sr_no, :sentiment, :voted).to_h
    filters.delete("voted") unless %w[yes no].include?(filters["voted"])
    filters
  end

  def require_voter_access
    return if current_user.role.can_access?("voter_lists")

    redirect_to root_path, alert: "You don't have access to Voter Lists."
  end

  def require_voter_write
    return if current_user.role.can_write?("voter_lists")

    redirect_to voters_path, alert: "You can't update the voter list."
  end

  def current_organization
    current_user.organization
  end
end
