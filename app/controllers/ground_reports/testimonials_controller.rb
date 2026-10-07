module GroundReports
  # Add another testimonial to a report the viewer may already see (Story 3.1).
  class TestimonialsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_ground_reports_access

    def create
      village = current_user.organization.villages.find(params[:village_id])
      report = policy_scope(GroundReport).find(params[:report_id])
      testimonial = report.testimonials.new(testimonial_params)
      testimonial.created_by = current_user
      authorize testimonial
      if testimonial.save
        redirect_to ground_reports_village_report_path(village, report), notice: "Testimonial added."
      else
        redirect_to ground_reports_village_report_path(village, report),
                    alert: testimonial.errors.full_messages.to_sentence
      end
    end

    private

    def testimonial_params
      params.require(:ground_report_testimonial).permit(:person_name, :content_type, :text_content, :media)
    end

    def require_ground_reports_access
      return if current_user.role.can_access?("ground_reports")

      redirect_to root_path, alert: "You don't have access to Ground Reports."
    end
  end
end
