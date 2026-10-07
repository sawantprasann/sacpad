module GroundReports
  # A non-system administrative contact, such as a sarpanch or gram sevak (Story 3.3, FR29).
  class VillageLocalAdminContact < ApplicationRecord
    self.table_name = "village_local_admin_contacts"

    include OrganizationScoped
    include SoftDeletable
    include VillageInConstituency

    belongs_to :village

    validates :name, :role_title, presence: true
  end
end
