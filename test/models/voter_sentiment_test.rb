require "test_helper"

# Story 1.7 — VoterSentiment#record_sentiment! (org-scoped, attributed, timestamped, Tier-1 versioned).
class VoterSentimentTest < ActiveSupport::TestCase
  setup do
    @org  = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @role = ActsAsTenant.without_tenant { Role.create!(name: "Field", slug: "field") }
    @user = ActsAsTenant.without_tenant do
      User.create!(organization: @org, role: @role, name: "U", email: "u@example.com", password: "password123")
    end
  end

  test "record_sentiment! writes status + updated_by/at and a Tier-1 version" do
    voter = Voter.create!(voter_id: "V1", first_name: "Asha", last_name: "Kumar")

    ActsAsTenant.with_tenant(@org) do
      voter_sentiment = VoterSentiment.create!(voter: voter, organization: @org)
      assert_difference -> { voter_sentiment.versions.count }, 1 do
        voter_sentiment.record_sentiment!("pleased", by: @user)
      end
      voter_sentiment.reload
      assert voter_sentiment.sentiment_pleased?
      assert_equal @user.id, voter_sentiment.sentiment_updated_by_id
      assert_not_nil voter_sentiment.sentiment_updated_at
    end
  end

  test "sentiment enum maps to RAG colors" do
    voter = Voter.create!(voter_id: "S1", first_name: "A", last_name: "Test")

    ActsAsTenant.with_tenant(@org) do
      s = VoterSentiment.create!(voter: voter, organization: @org, sentiment_status: "pleased")
      assert_equal :green, s.rag_color
      s.update!(sentiment_status: "displeased")
      assert_equal :red, s.rag_color
    end
  end

  test "org-scoped — rival orgs track independent sentiment for same voter" do
    org_b = ActsAsTenant.without_tenant { Organization.create!(name: "Org B") }
    voter = Voter.create!(voter_id: "SHARED", first_name: "Shared", last_name: "Voter")

    ActsAsTenant.with_tenant(@org) do
      s_a = VoterSentiment.create!(voter: voter, organization: @org, sentiment_status: "pleased")
      assert_equal :green, s_a.rag_color
    end

    ActsAsTenant.with_tenant(org_b) do
      s_b = VoterSentiment.create!(voter: voter, organization: org_b, sentiment_status: "displeased")
      assert_equal :red, s_b.rag_color
    end
  end
end
