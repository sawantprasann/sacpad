module GroundReports
  # Villages the organization covers, then the reports logged in each one (Story 3.1).
  # Show also loads worship places, political history, work inline, local contacts, and the mock poll.
  class VillagesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_ground_reports_access

    def index
      authorize GroundReport, :index?
      scope = current_user.organization.villages
      @talukas = Taluka.where(id: scope.where.not(taluka_id: nil).select(:taluka_id)).order(:name)
      relation = scope.includes(:taluka).order(:name)
      relation = relation.where(taluka_id: params[:taluka_id]) if params[:taluka_id].present?
      # Village choices follow the taluka filter and stay alphabetical, same as the taluka list.
      @filter_villages = relation.reorder(:name)
      relation = relation.where(id: params[:village_id]) if params[:village_id].present?
      @pagy, @villages = pagy(:offset, relation)
      @nidhi_totals = GroundReports::VillageWork.kept.where(village_id: @villages.map(&:id)).group(:village_id).sum(:nidhi_asked)
    end

    def show
      authorize GroundReport, :index?
      @village = current_user.organization.villages.find(params[:id])
      reports = policy_scope(GroundReport).where(village_id: @village.id)
                                           .includes(:owner, :testimonials)
                                           .order(reported_at: :desc, id: :desc)
      load_village_record
      respond_to do |format|
        format.html { @pagy, @reports = pagy(:offset, reports) }
        format.xlsx do
          # Full viewer-scoped set, not the page on screen.
          @reports = reports
          response.headers["Content-Disposition"] = "attachment; filename=#{export_filename}"
        end
      end
    end

    private

    def load_village_record
      @worship_places = WorshipPlace.kept.where(village: @village).order(:name)
      @works = VillageWork.kept.where(village: @village).with_attached_attachments.order(created_at: :desc)
      @total_nidhi = VillageWork.kept.where(village: @village).sum(:nidhi_asked)
      @positions = VillagePoliticalPosition.kept.where(village: @village).includes(:party).order(started_at: :desc, id: :desc)
      @parties = Party.order(:name)
      @karyakartas = VillageLocalKaryakarta.kept.where(village: @village).order(:name)
      @admin_contacts = VillageLocalAdminContact.kept.where(village: @village).includes(:admin_contact_role).order(:name)
      @admin_roles = AdminContactRole.active
      @poll_responses = MockPollResponse.kept.where(village: @village).includes(:politician).order(created_at: :desc, id: :desc)
      @poll_tally = MockPollResponse.tally_for(@village)
      @likely_winners = MockPollResponse.likely_winners(@poll_tally)
      @politicians = Politician.order(:name)
    end

    def export_filename
      slug = @village.name.to_s.parameterize.presence || @village.id
      "ground-report-#{slug}.xlsx"
    end

    def require_ground_reports_access
      return if current_user.role.can_access?("ground_reports")

      redirect_to root_path, alert: t("ground_reports.no_access")
    end
  end
end
