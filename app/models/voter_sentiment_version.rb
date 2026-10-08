# Tier-1 custom PaperTrail version class for VoterSentiment (§7a) — dedicated audit table
# for tracking org-scoped sentiment changes.
class VoterSentimentVersion < PaperTrail::Version
  self.table_name = "voter_sentiment_versions"
end
