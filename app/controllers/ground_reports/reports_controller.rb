module GroundReports
  # Capture and read a village report (Story 3.1). The village comes from the URL and must
  # sit in the organization's constituency. organization_id is never taken from params.
  class ReportsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_ground_reports_access
    before_action :set_village
    before_action :set_report, only: %i[edit update destroy]

    def show
      @report = policy_scope(GroundReport).includes(testimonials: { media_attachment: :blob }).find(params[:id])
      authorize @report
      @testimonial = @report.testimonials.new(content_type: :text)
    end

    def new
      @report = @village.ground_reports.new
      @report.testimonials.build(content_type: :text)
      authorize @report
    end

    def create
      @report = @village.ground_reports.new(report_params)
      @report.owner = current_user
      @report.organization = current_user.organization
      authorize @report
      if @report.save
        record_activity("ground_report.created", record: @report)
        redirect_to ground_reports_village_report_path(@village, @report), notice: "Issue logged."
      else
        @report.testimonials.build(content_type: :text) if @report.testimonials.empty?
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @report.update(report_params)
        record_activity("ground_report.updated", record: @report)
        redirect_to ground_reports_village_path(@village), notice: "Issue updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @report.discard_by(current_user)
      record_activity("ground_report.discarded", record: @report)
      redirect_to ground_reports_village_path(@village), notice: "Issue deleted."
    end

    private

    def set_village
      @village = current_user.organization.villages.find(params[:village_id])
    end

    def set_report
      @report = policy_scope(GroundReport).where(village_id: @village.id).find(params[:id])
      authorize @report
    end

    def report_params
      params.require(:ground_report).permit(
        :issue_text, :resolution_text, :estimated_cost, :reported_at,
        testimonials_attributes: %i[person_name content_type text_content media]
      )
    end

    def require_ground_reports_access
      return if current_user.role.can_access?("ground_reports")

      redirect_to root_path, alert: "You don't have access to Ground Reports."
    end
  end
end
