class Voter < ApplicationRecord
  # Global electoral-roll record — shared data across all organizations (§6.7 v2).
  # Only voter data (voter_id, name, mobile, booth) is global; sentiment tracking is org-scoped
  # via VoterSentiment table. The Voter Lists bulk-import experience (Epic 6) uploads once here,
  # and all orgs reference the same records.
  include FullyVersioned   # Tier-1 VoterVersion history for PII edits

  belongs_to :booth, optional: true
  belongs_to :state, optional: true
  belongs_to :loksabha, optional: true
  belongs_to :assembly, optional: true
  belongs_to :village, optional: true
  has_many :voter_sentiments, dependent: :destroy

  # PII encrypted at rest (NFR18). voter_id is deterministic so the loose Ticket lookup can query it.
  encrypts :voter_id, deterministic: true
  encrypts :first_name
  encrypts :last_name
  encrypts :middle_name
  encrypts :mobile

  validates :first_name, :last_name, presence: true
end
