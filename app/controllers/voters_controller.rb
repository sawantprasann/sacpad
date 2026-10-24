# Org-side voter management. Sentiment and voted are stored per organization.
class VotersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_voter_access
  before_action :require_voter_write, only: %i[update_voted update_mobile]
  before_action :set_voter, only: %i[show update_voted update_mobile]
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
    @villages = current_user.visible_villages(current_organization.villages).order(:name)
    booths = Booth.where(village_id: @villages.select(:id))
    booths = booths.where(id: current_user.booth_id) if current_user.booth_manager?
    @booth_numbers = booths.by_number.pluck(:number).uniq
  end

  def show
    @election = Election.ensure_current!(current_organization)
    @turnout = VoterTurnout.find_by(election: @election, voter: @voter)
  end

  def update_voted
    election = Election.ensure_current!(current_organization)
    voted = ActiveModel::Type::Boolean.new.cast(params[:voted])
    VoterTurnout.mark!(election: election, voter: @voter, voted: voted, by: current_user)
    redirect_back fallback_location: voted_return_path,
                  notice: voted ? "Marked as voted for #{election.name}." : "Marked as not voted for #{election.name}."
  end

  def update_mobile
    digits = params[:mobile].to_s.gsub(/\D/, "")
    unless digits.match?(/\A\d{10}\z/)
      redirect_to voter_path(@voter), alert: "Enter a 10-digit mobile number."
      return
    end

    if @voter.update(mobile: digits)
      redirect_to voter_path(@voter), notice: "Mobile number saved."
    else
      redirect_to voter_path(@voter), alert: @voter.errors.full_messages.to_sentence.presence || "Couldn't save the mobile number."
    end
  end

  private

  def set_voter
    @voter = current_user.visible_voters.find(params[:id])
  end

  def filtered_voters
    relation = current_user.visible_voters
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

  def voter_filters
    filters = params.permit(:voter_id, :name, :booth, :village_id, :sr_no, :sentiment, :voted).to_h
    filters.delete("voted") unless %w[yes no].include?(filters["voted"])
    filters
  end

  def voted_return_path
    candidate = params[:return_to].to_s
    return candidate if candidate.match?(%r{\A/[^\s\\]*\z}) && !candidate.start_with?("//")

    voters_path(voter_filters)
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
