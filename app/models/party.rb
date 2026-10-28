class Party < ApplicationRecord
  # Global party reference data (§3.1b), Admin-managed. Org affiliation history lives in
  # party_memberships (later); here is just the shared catalog.
  has_one_attached :logo
  has_many :election_candidates, class_name: "ConstituencyElectionCandidate", dependent: :restrict_with_error
  has_many :gained_election_results, class_name: "ConstituencyElection", foreign_key: :gained_from_party_id, inverse_of: :gained_from_party, dependent: :restrict_with_error
  validates :name, presence: true
end
