require "test_helper"

# Story 1.7 — Voter#record_sentiment! (attributed, timestamped, Tier-1 versioned).
class VoterSentimentTest < ActiveSupport::TestCase
  setup do
    @org  = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @role = ActsAsTenant.without_tenant { Role.create!(name: "Field", slug: "field") }
    @user = ActsAsTenant.without_tenant do
      User.create!(organization: @org, role: @role, name: "U", email: "u@example.com", password: "password123")
    end
  end

  test "record_sentiment! writes status + updated_by/at and a Tier-1 version" do
    ActsAsTenant.with_tenant(@org) do
      voter = Voter.create!(voter_id: "V1", name: "Asha")
      assert_difference -> { voter.versions.count }, 1 do
        voter.record_sentiment!("pleased", by: @user)
      end
      voter.reload
      assert voter.sentiment_pleased?
      assert_equal @user.id, voter.sentiment_updated_by_id
      assert_not_nil voter.sentiment_updated_at
    end
  end
end
