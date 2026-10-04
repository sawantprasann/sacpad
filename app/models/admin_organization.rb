class AdminOrganization < ApplicationRecord
  belongs_to :admin
  belongs_to :organization
  validates :admin_id, uniqueness: { scope: :organization_id }
end
