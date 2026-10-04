# Tier-1 full version history (§7a) via PaperTrail with a CUSTOM per-model version class/table
# (e.g. VoterVersion, UserVersion) — not one shared `versions` table. Each including model must
# define its `<Model>Version < PaperTrail::Version` with its own table. First live use: Voter (0.15).
module FullyVersioned
  extend ActiveSupport::Concern

  included do
    has_paper_trail versions: { class_name: "#{name}Version" }
  end
end
