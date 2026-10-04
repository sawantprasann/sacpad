# Tenant-isolation convention for EVERY domain model (architecture §Data boundary).
# Including this:
#   - declares acts_as_tenant(:organization) so queries auto-scope to the current org
#     and RAISE when no tenant is set (require_tenant = true),
#   - requires a denormalized organization_id (belt-and-suspenders beyond hierarchy scoping),
#   - the migration for the including model MUST add organization_id as NOT NULL + FK (layer 4).
#
# Usage (later stories):
#   class Ticket < ApplicationRecord
#     include OrganizationScoped
#   end
module OrganizationScoped
  extend ActiveSupport::Concern

  included do
    acts_as_tenant(:organization)
    validates :organization_id, presence: true
  end
end
