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

  # PII encrypted at rest (NFR18). Name fields deterministic for searchability.
  # voter_id is deterministic for Ticket lookup; name fields deterministic for voter search/filter.
  encrypts :voter_id, deterministic: true
  encrypts :first_name, deterministic: true
  encrypts :last_name, deterministic: true
  encrypts :middle_name, deterministic: true
  encrypts :mobile

  validates :first_name, :last_name, presence: true
end
