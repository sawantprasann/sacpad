module GroundReports
  # Development work recorded for a village: the letter, the fund asked, and the work order.
  class VillageWork < ApplicationRecord
    self.table_name = "village_works"

    include OrganizationScoped
    include SoftDeletable
    include VillageInConstituency

    NIDHI_CATEGORY_LABELS = {
      "mla_fund" => "MLA fund",
      "dpdc" => "DPDC",
      "scheme_25_15" => "25-15",
      "scheme_30_54" => "30-54",
      "other" => "Other"
    }.freeze

    belongs_to :village
    has_many_attached :attachments

    enum :nidhi_category, {
      mla_fund: 0,
      dpdc: 1,
      scheme_25_15: 2,
      scheme_30_54: 3,
      other: 4
    }, prefix: :nidhi
    enum :status, { not_started: 0, in_progress: 1, completed: 2 }

    validates :title, :concern_person, :nidhi_category, :status, presence: true
    validates :nidhi_asked, numericality: { greater_than_or_equal_to: 0 }
    validates :nidhi_category_name, presence: true, if: :nidhi_other?

    def nidhi_label
      return nidhi_category_name if nidhi_other? && nidhi_category_name.present?

      NIDHI_CATEGORY_LABELS[nidhi_category]
    end
  end
end
