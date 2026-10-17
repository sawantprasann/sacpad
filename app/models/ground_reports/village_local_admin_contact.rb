module GroundReports
  # A non-system administrative contact, such as a sarpanch or gram sevak (Story 3.3, FR29).
  class VillageLocalAdminContact < ApplicationRecord
    self.table_name = "village_local_admin_contacts"

    include OrganizationScoped
    include SoftDeletable
    include VillageInConstituency

    belongs_to :village
    belongs_to :admin_contact_role, optional: true

    validates :name, :role_title, presence: true

    before_validation :copy_role_title

    private

    def copy_role_title
      self.role_title = admin_contact_role.name if admin_contact_role
    end
  end
end
