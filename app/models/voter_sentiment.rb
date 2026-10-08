class VoterSentiment < ApplicationRecord
  # Org-scoped sentiment tracking for voters (§6.7 v2). Each organization independently
  # tracks their own sentiment for a shared voter record. Paired with global Voter table.
  include OrganizationScoped
  include FullyVersioned

  belongs_to :voter
  belongs_to :organization

  # Sentiment maps to RAG presentation (pleased=green, transit=amber, displeased=red).
  enum :sentiment_status, { pleased: 0, transit: 1, displeased: 2 }, prefix: :sentiment

  validates :voter, presence: true
  validates :voter_id, uniqueness: { scope: :organization_id }

  def rag_color
    { "pleased" => :green, "transit" => :amber, "displeased" => :red }[sentiment_status]
  end

  # Record a sentiment reading (Story 1.7 closure). Attributed + timestamped; the change is captured
  # in VoterSentimentVersion automatically (Tier-1 history, FR43).
  def record_sentiment!(status, by:)
    update!(sentiment_status: status, sentiment_updated_by_id: by.id, sentiment_updated_at: Time.current)
  end
end
