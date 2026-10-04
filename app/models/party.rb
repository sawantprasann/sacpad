class Party < ApplicationRecord
  # Global party reference data (§3.1b), Admin-managed. Org affiliation history lives in
  # party_memberships (later); here is just the shared catalog.
  has_one_attached :logo
  validates :name, presence: true
end
