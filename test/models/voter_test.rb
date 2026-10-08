require "test_helper"

# Story 0.15 — the Voter primitive (v2): GLOBAL electoral-roll record, PII-encrypted, Tier-1 versioning.
# Sentiment tracking moved to org-scoped VoterSentiment model.
class VoterTest < ActiveSupport::TestCase
  test "PII is encrypted at rest but readable through the model" do
    voter = Voter.create!(voter_id: "X9", first_name: "Secret", last_name: "Name", mobile: "9999")
    raw = Voter.connection.select_one("SELECT first_name, voter_id FROM voters WHERE id = #{voter.id}")
    assert_not_equal "Secret", raw["first_name"], "first_name column must be ciphertext at rest"
    assert_equal "Secret", voter.reload.first_name, "model decrypts transparently"
  end

  test "deterministic voter_id is queryable (loose Ticket lookup key)" do
    Voter.create!(voter_id: "VID123", first_name: "A", last_name: "Test")
    assert Voter.find_by(voter_id: "VID123"), "deterministic encryption allows lookup by voter_id"
  end

  test "Tier-1 versioning records a dedicated VoterVersion on change" do
    v = Voter.create!(voter_id: "V1", first_name: "A", last_name: "Test")
    assert_difference -> { VoterVersion.where(item_id: v.id).count }, 1 do
      v.update!(first_name: "B")
    end
  end
end
