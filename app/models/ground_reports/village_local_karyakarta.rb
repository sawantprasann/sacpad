module GroundReports
  # A village karyakarta recorded as contact info, not a system User (Story 3.3, FR29).
  class VillageLocalKaryakarta < ApplicationRecord
    self.table_name = "village_local_karyakartas"

    include OrganizationScoped
    include SoftDeletable
    include VillageInConstituency

    belongs_to :village

    validates :name, presence: true
  end
end
