require "test_helper"

class GroundReports::MockPollResponseTest < ActiveSupport::TestCase
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @other = ActsAsTenant.without_tenant { Organization.create!(name: "Org B") }
    state = State.create!(name: "Maharashtra")
    assembly = state.loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur")
    @village = assembly.villages.create!(name: "Nimgaon")
    @outside = assembly.loksabha.assemblies.create!(name: "Elsewhere").villages.create!(name: "Far")
    @org.update!(constituency: assembly)
    @other.update!(constituency: assembly)
    role = Role.create!(name: "Field", slug: "poll-field")
    @user = User.create!(organization: @org, role: role, name: "Rohan", email: "poll@example.com", password: "password123")
  end

  test "responses tally on read and do not use a stored tally table" do
    assert_not ActiveRecord::Base.connection.table_exists?("mock_poll_tallies")

    ActsAsTenant.with_tenant(@org) do
      own = Politician.create!(name: "Meera Patil", is_own_politician: true)
      opponent = Politician.create!(name: "Ravi Kale")
      attrs = { village: @village, created_by: @user, preference_basis: :individual }

      GroundReports::MockPollResponse.create!(attrs.merge(politician: own, respondent_name: "Asha", vote_choice: "yes"))
      GroundReports::MockPollResponse.create!(attrs.merge(politician: own, respondent_name: "Ramesh", preference_basis: :party, vote_choice: "yes"))
      GroundReports::MockPollResponse.create!(attrs.merge(politician: opponent, respondent_name: "Asha", vote_choice: "no"))
      undecided = GroundReports::MockPollResponse.create!(attrs.merge(politician: opponent, respondent_name: "Lata", vote_choice: "undecided"))
      assert_nil undecided.vote_intent

      rows = GroundReports::MockPollResponse.tally_for(@village)
      own_row = rows.find { |row| row[:politician] == own }
      opponent_row = rows.find { |row| row[:politician] == opponent }
      assert_equal 2, own_row[:yes]
      assert_equal 1, opponent_row[:no]
      assert_equal 1, opponent_row[:undecided]
      assert_equal [ own ], GroundReports::MockPollResponse.likely_winners(rows)

      outside = GroundReports::MockPollResponse.new(attrs.merge(village: @outside, politician: own, respondent_name: "Far", vote_choice: "yes"))
      assert_not outside.save
      assert outside.errors[:village].any?
    end

    outsider = ActsAsTenant.with_tenant(@other) { Politician.create!(name: "Other Candidate") }
    ActsAsTenant.with_tenant(@org) do
      taken = GroundReports::MockPollResponse.new(
        village: @village, politician_id: outsider.id, created_by: @user,
        respondent_name: "Asha", preference_basis: :party, vote_choice: "yes"
      )
      assert_not taken.save
      assert taken.errors[:politician].any?
    end
  end

  test "a tie marks every politician with the most yes votes" do
    ActsAsTenant.with_tenant(@org) do
      own = Politician.create!(name: "Meera Patil", is_own_politician: true)
      opponent = Politician.create!(name: "Ravi Kale")
      attrs = { village: @village, created_by: @user, preference_basis: :individual, vote_choice: "yes" }
      GroundReports::MockPollResponse.create!(attrs.merge(politician: own, respondent_name: "Asha"))
      GroundReports::MockPollResponse.create!(attrs.merge(politician: opponent, respondent_name: "Ramesh"))

      winners = GroundReports::MockPollResponse.likely_winners(GroundReports::MockPollResponse.tally_for(@village))
      assert_equal [ own, opponent ].sort_by(&:name), winners.sort_by(&:name)
    end
  end
end
