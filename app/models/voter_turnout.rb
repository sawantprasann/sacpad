class VoterTurnout < ApplicationRecord
  # Whether this organization marked a shared voter as voted in one election.
  include OrganizationScoped

  belongs_to :election
  belongs_to :voter

  validates :voter_id, uniqueness: { scope: :election_id }

  def self.mark!(election:, voter:, voted:, by:)
    row = find_or_initialize_by(election: election, voter: voter)
    row.organization = election.organization
    row.update!(
      voted: voted,
      voted_at: (Time.current if voted),
      voted_by_id: by.id
    )
    row
  end
end
