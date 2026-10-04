require "test_helper"
require_relative "../support/tenant_isolation"

# Story 0.15 — the Voter primitive: org-scoped, PII-encrypted, sentiment, Tier-1 versioning.
class VoterTest < ActiveSupport::TestCase
  include TenantIsolation

  setup do
    @org_a = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @org_b = ActsAsTenant.without_tenant { Organization.create!(name: "Org B") }
  end

  test "is org-scoped (tenant-isolated) — rival orgs never share a voter" do
    b_voter = ActsAsTenant.with_tenant(@org_b) { Voter.create!(voter_id: "B1", name: "B") }
    ActsAsTenant.with_tenant(@org_a) { Voter.create!(voter_id: "A1", name: "A") }
    assert_tenant_isolated(Voter, owner: @org_a, foreign_record: b_voter)
  end

  test "PII is encrypted at rest but readable through the model" do
    voter = ActsAsTenant.with_tenant(@org_a) { Voter.create!(voter_id: "X9", name: "Secret Name", mobile: "9999") }
    raw = Voter.connection.select_one("SELECT name, voter_id FROM voters WHERE id = #{voter.id}")
    assert_not_equal "Secret Name", raw["name"], "name column must be ciphertext at rest"
    assert_equal "Secret Name", voter.reload.name, "model decrypts transparently"
  end

  test "deterministic voter_id is queryable (loose Ticket lookup key)" do
    ActsAsTenant.with_tenant(@org_a) do
      Voter.create!(voter_id: "VID123", name: "A")
      assert Voter.find_by(voter_id: "VID123"), "deterministic encryption allows lookup by voter_id"
    end
  end

  test "sentiment enum maps to RAG colors" do
    ActsAsTenant.with_tenant(@org_a) do
      v = Voter.create!(voter_id: "S1", name: "A", sentiment_status: "pleased")
      assert_equal :green, v.rag_color
      v.update!(sentiment_status: "displeased")
      assert_equal :red, v.rag_color
    end
  end

  test "Tier-1 versioning records a dedicated VoterVersion on change" do
    ActsAsTenant.with_tenant(@org_a) do
      v = Voter.create!(voter_id: "V1", name: "A", sentiment_status: "transit")
      assert_difference -> { VoterVersion.where(item_id: v.id).count }, 1 do
        v.update!(sentiment_status: "pleased")
      end
    end
  end
end
