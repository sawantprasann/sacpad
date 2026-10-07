module GroundReports
  # Village issue and resolution (Story 3.1, FR27). Testimonials hang off this row.
  # Table name is pinned — a namespaced model would otherwise seek ground_reports_ground_reports.
  class GroundReport < ApplicationRecord
    self.table_name = "ground_reports"

    include OrganizationScoped
    include SoftDeletable

    belongs_to :owner, class_name: "User"
    belongs_to :village
    has_many :testimonials, class_name: "GroundReports::GroundReportTestimonial",
                            inverse_of: :ground_report

    accepts_nested_attributes_for :testimonials, reject_if: :blank_testimonial?

    validates :issue_text, :reported_at, presence: true
    validate :village_in_constituency

    after_initialize :set_reported_at, if: :new_record?

    private

    def set_reported_at
      self.reported_at ||= Date.current
    end

    def village_in_constituency
      return if village_id.blank? || organization.blank?
      return if organization.villages.exists?(id: village_id)

      errors.add(:village, "is outside this constituency")
    end

    def blank_testimonial?(attrs)
      attrs["person_name"].blank? && attrs["text_content"].blank? && attrs["media"].blank?
    end
  end
end
