module GroundReports
  # Adding a testimonial is a write on a report the viewer may already see.
  class GroundReportTestimonialPolicy < ApplicationPolicy
    def create?
      user.role.can_write?("ground_reports") &&
        record.ground_report.owner_id.in?(user.subtree_user_ids)
    end
  end
end
