module GroundReports
  # One editable yatra note per village per organization (Story 3.2, FR28).
  class VillageYatra < ApplicationRecord
    self.table_name = "village_yatras"

    include OrganizationScoped
    include VillageInConstituency

    belongs_to :village
    belongs_to :updated_by, class_name: "User", optional: true

    validates :village_id, uniqueness: { scope: :organization_id }
  end
end
