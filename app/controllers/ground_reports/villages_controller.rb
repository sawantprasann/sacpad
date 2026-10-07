module GroundReports
  # Villages the organization covers, then the reports logged in each one (Story 3.1).
  # Show also loads worship places, the yatra note, political history (Story 3.2),
  # local contacts who are not system users (Story 3.3), and the mock poll (Story 3.4).
  class VillagesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_ground_reports_access

    def index
      authorize GroundReport, :index?
      relation = current_user.organization.villages.includes(:assembly).order(:name)
      @pagy, @villages = pagy(:offset, relation)
    end

    def show
      authorize GroundReport, :index?
      @village = current_user.organization.villages.find(params[:id])
      relation = policy_scope(GroundReport).where(village_id: @village.id)
                                           .includes(:owner, :testimonials)
                                           .order(reported_at: :desc, id: :desc)
      @pagy, @reports = pagy(:offset, relation)
      @worship_places = WorshipPlace.where(village: @village).order(:name)
      @yatra = VillageYatra.find_or_initialize_by(village: @village)
      @positions = VillagePoliticalPosition.where(village: @village).includes(:party).order(started_at: :desc, id: :desc)
      @parties = Party.order(:name)
      @karyakartas = VillageLocalKaryakarta.where(village: @village).order(:name)
      @admin_contacts = VillageLocalAdminContact.where(village: @village).order(:name)
      @poll_responses = MockPollResponse.where(village: @village).includes(:politician).order(created_at: :desc, id: :desc)
      @poll_tally = MockPollResponse.tally_for(@village)
      @likely_winners = MockPollResponse.likely_winners(@poll_tally)
      @politicians = Politician.order(:name)
    end

    private

    def require_ground_reports_access
      return if current_user.role.can_access?("ground_reports")

      redirect_to root_path, alert: "You don't have access to Ground Reports."
    end
  end
end
