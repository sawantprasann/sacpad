module BoothManagement
  class BoothsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_booth_access
    helper_method :booth_filters

    def index
      @election = Election.ensure_current!(current_user.organization)
      @villages = current_user.organization.villages.order(:name)
      @station_types = booths.where.not(station_type: [ nil, "" ]).distinct.order(:station_type).pluck(:station_type)
      relation = filtered_booths
      @pagy, @booths = pagy(:offset, relation)
      ids = @booths.map(&:id)
      @voter_counts = Voter.where(booth_id: ids).group(:booth_id).count
      voted_ids = VoterTurnout.where(election: @election, voted: true).select(:voter_id)
      @voted_counts = Voter.where(booth_id: ids, id: voted_ids).group(:booth_id).count
    end

    def show
      @booth = booths.find(params[:id])
      @election = Election.ensure_current!(current_user.organization)
      @voter_count = @booth.voters.count
      @voted_count = @booth.voters.where(id: VoterTurnout.where(election: @election, voted: true).select(:voter_id)).count
    end

    private

    def booths
      Booth.where(village_id: current_user.organization.villages.select(:id))
    end

    def filtered_booths
      relation = booths.includes(village: :assembly).references(:village)
      if params[:number].present?
        relation = relation.where("booths.number ILIKE ?", like(params[:number]))
      end
      if params[:name].present?
        relation = relation.where("booths.name ILIKE ?", like(params[:name]))
      end
      relation = relation.where(village_id: params[:village_id]) if params[:village_id].present?
      if params[:address].present?
        relation = relation.where("booths.address ILIKE ?", like(params[:address]))
      end
      if params[:station_type].present?
        relation = relation.where(station_type: params[:station_type])
      end
      relation.order("villages.name", "booths.number")
    end

    def booth_filters
      params.permit(:number, :name, :village_id, :address, :station_type).to_h
    end

    def like(value)
      "%#{Booth.sanitize_sql_like(value.to_s.strip)}%"
    end

    def require_booth_access
      return if current_user.role.can_access?("booth_management")

      redirect_to root_path, alert: "You don't have access to Booth Management."
    end
  end
end
