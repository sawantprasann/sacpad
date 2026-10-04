# Tier-1 custom PaperTrail version class for Voter (§7a) — its own dedicated table,
# not a shared `versions` table.
class VoterVersion < PaperTrail::Version
  self.table_name = "voter_versions"
end
