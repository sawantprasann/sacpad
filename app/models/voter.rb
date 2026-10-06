class Voter < ApplicationRecord
  # Org-owned electoral-roll record (§6.7). The full Voter Lists experience (import, filtered
  # lookup, PII access controls) is Epic 6; this primitive exists so Kitchen Cabinet (Story 1.7)
  # can write sentiment without depending on Epic 6.
  include OrganizationScoped
  include FullyVersioned   # Tier-1 VoterVersion history (PII/sentiment edits)

  belongs_to :booth, optional: true

  # PII encrypted at rest (NFR18). voter_id is deterministic so the loose Ticket lookup can query it.
  encrypts :voter_id, deterministic: true
  encrypts :name
  encrypts :mobile

  # Mutable; maps to RAG presentation (pleased=green, transit=amber, displeased=red) — not stored.
  enum :sentiment_status, { pleased: 0, transit: 1, displeased: 2 }, prefix: :sentiment

  def rag_color
    { "pleased" => :green, "transit" => :amber, "displeased" => :red }[sentiment_status]
  end

  # Record a sentiment reading (Story 1.7 closure). Attributed + timestamped; the change is captured
  # in VoterVersion automatically (Tier-1 history, FR43).
  def record_sentiment!(status, by:)
    update!(sentiment_status: status, sentiment_updated_by_id: by.id, sentiment_updated_at: Time.current)
  end
end
