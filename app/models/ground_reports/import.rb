module GroundReports
  # One uploaded workbook for reports or mock poll (Story 3.5, FR31).
  class Import < ApplicationRecord
    self.table_name = "ground_report_imports"

    include OrganizationScoped

    belongs_to :user
    has_one_attached :file

    enum :kind, { report: 0, mock_poll: 1 }, validate: true
    enum :status, { pending: 0, completed: 1 }, default: :pending, validate: true

    validate :file_present

    private

    def file_present
      errors.add(:file, "can't be blank") unless file.attached?
    end
  end
end
