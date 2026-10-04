class PartyMembership < ApplicationRecord
  # History-preserving affiliation (§3.1b): changing party closes the old row and opens a new one.
  belongs_to :organization
  belongs_to :party
  validates :started_at, presence: true
  scope :active, -> { where(ended_at: nil) }
end
