module VoterLists
  class VillagesController < BaseController
    before_action :set_village
    helper_method :voter_filters

    def show
      @election = Election.ensure_current!(current_user.organization)
      roll = current_user.visible_voters(@village.voters)
      @voter_total = roll.count
      booths = @village.booths
      booths = booths.where(id: current_user.booth_id) if current_user.booth_manager?
      @booth_numbers = booths.by_number.pluck(:number).uniq
      voters = listed_voters
      respond_to do |format|
        format.html do
          @pagy, @voters = pagy(:offset, voters)
          load_roll_state(@voters)
        end
        format.xlsx do
          @voters = voters
          load_roll_state(@voters)
          response.headers["Content-Disposition"] = "attachment; filename=#{export_filename}"
        end
      end
    end

    private

    def set_village
      @taluka = organization_talukas.find(params[:taluka_id])
      @village = organization_villages.where(taluka_id: @taluka.id).includes(:assembly, :taluka, :police_station_record).find(params[:id])
    end

    # The village bounds the set. Export uses the same booth-then-serial order as the list.
    # A name search still loads the rows, because names are encrypted.
    def listed_voters
      relation = current_user.visible_voters(@village.voters.preload(:booth, :village))
      relation = relation.where(voter_id: params[:voter_id].strip) if params[:voter_id].present?
      relation = filter_sr_no(relation)
      if params[:booth].present?
        booth_ids = @village.booths.where(number: params[:booth].strip).select(:id)
        relation = relation.where(booth_id: booth_ids)
      end
      if VoterSentiment.sentiment_statuses.key?(params[:sentiment])
        ids = VoterSentiment.where(sentiment_status: params[:sentiment]).select(:voter_id)
        relation = relation.where(id: ids)
      end
      if params[:voted] == "yes"
        relation = relation.where(id: voted_ids)
      elsif params[:voted] == "no"
        relation = relation.where.not(id: voted_ids)
      end
      relation = relation.by_booth_and_serial
      return relation unless params[:name].present?

      relation.to_a.select { |voter| voter.matches_name?(params[:name]) }
    end

    def filter_sr_no(relation)
      return relation if params[:sr_no].blank?

      sr_no = Integer(params[:sr_no], exception: false)
      sr_no ? relation.where(sr_no: sr_no) : relation.none
    end

    def voted_ids
      VoterTurnout.where(election: @election, voted: true).select(:voter_id)
    end

    def load_roll_state(voters)
      ids = voters.map(&:id)
      @sentiments = VoterSentiment.where(voter_id: ids).index_by(&:voter_id)
      @turnouts = VoterTurnout.where(election: @election, voter_id: ids).index_by(&:voter_id)
    end

    def voter_filters
      filters = params.permit(:voter_id, :name, :booth, :sr_no, :sentiment, :voted).to_h.symbolize_keys
      filters.delete(:voted) unless %w[yes no].include?(filters[:voted])
      filters.delete(:sentiment) unless VoterSentiment.sentiment_statuses.key?(filters[:sentiment])
      filters
    end

    def export_filename
      slug = @village.name.to_s.parameterize.presence || @village.id
      "voters-#{slug}.xlsx"
    end
  end
end
