module GroundReports
  # Villager feedback on a report (Story 3.1, FR27). Text is stored on the row.
  # Audio and video files go through Active Storage.
  class GroundReportTestimonial < ApplicationRecord
    self.table_name = "ground_report_testimonials"

    include OrganizationScoped
    include SoftDeletable

    belongs_to :ground_report, class_name: "GroundReports::GroundReport", inverse_of: :testimonials
    belongs_to :created_by, class_name: "User"
    has_one_attached :media

    enum :content_type, { text: 0, audio: 1, video: 2 }

    validates :person_name, :content_type, presence: true
    validate :content_matches_type

    before_validation :inherit_from_report

    private

    def inherit_from_report
      return unless ground_report

      self.organization_id ||= ground_report.organization_id
      self.created_by_id ||= ground_report.owner_id
    end

    def content_matches_type
      if text?
        errors.add(:text_content, "can't be blank") if text_content.blank?
      elsif (audio? || video?) && !media.attached?
        errors.add(:media, "must be attached")
      end
    end
  end
end
