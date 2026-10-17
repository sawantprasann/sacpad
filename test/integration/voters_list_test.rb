require "test_helper"

class VotersListTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    state = State.create!(name: "Maharashtra")
    assembly = state.loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur")
    @org.update!(constituency: assembly)
    @village = assembly.villages.create!(name: "Nimgaon")
    @other_village = assembly.villages.create!(name: "Kalas")
    @booth = @village.booths.create!(number: "14")
    @other_booth = @other_village.booths.create!(number: "2")
    @asha = Voter.create!(voter_id: "ABC1234567", first_name: "Asha", last_name: "Patil", sr_no: 12, booth: @booth, village: @village)
    @ravi = Voter.create!(voter_id: "XYZ7654321", first_name: "Ravi", last_name: "Kale", sr_no: 4, booth: @other_booth, village: @other_village)
    ActsAsTenant.with_tenant(@org) do
      VoterSentiment.create!(voter: @asha, sentiment_status: :pleased, voted: false)
    end

    role = Role.create!(name: "Booth Manager", slug: "booth-manager-test")
    role.role_permissions.create!(module_name: "voter_lists", access_level: "write")
    @user = User.create!(organization: @org, role: role, name: "Mina", email: "voters@example.com", password: "password123")
    sign_in @user
  end

  test "the index lists the roll and filters it" do
    get voters_path
    assert_response :success
    assert_match "ABC1234567", @response.body
    assert_match "XYZ7654321", @response.body
    assert_match "bg-green-50", @response.body

    get voters_path(voter_id: "ABC1234567", booth: "14", village_id: @village.id, sr_no: 12, name: "asha", sentiment: "pleased")
    assert_response :success
    assert_match "Asha", @response.body
    assert_no_match(/Ravi/, @response.body)
  end

  test "voted is stored for this organization only" do
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Org B", constituency: @org.constituency) }
    patch update_voted_voter_path(@asha), params: { voted: "1" }
    assert_redirected_to voters_path

    ActsAsTenant.with_tenant(@org) do
      row = VoterTurnout.find_by!(voter: @asha)
      assert row.voted?
      assert_includes row.election.name, "Indapur"
      assert_includes row.election.name, "Assembly"
    end
    ActsAsTenant.with_tenant(other) do
      assert_nil VoterTurnout.find_by(voter: @asha)
    end
  end

  test "moving the organization to a different constituency starts a new election" do
    patch update_voted_voter_path(@asha), params: { voted: "1" }
    previous = ActsAsTenant.with_tenant(@org) { VoterTurnout.find_by!(voter: @asha).election }

    loksabha = @org.constituency.loksabha
    @org.update!(constituency: loksabha)
    get voters_path
    assert_response :success
    assert_match "Baramati", @response.body
    assert_match "Loksabha", @response.body
    assert_match "Not voted", @response.body

    ActsAsTenant.with_tenant(@org) do
      current = Election.find_by!(current: true)
      assert_not_equal previous.id, current.id
      assert_equal "Loksabha", current.constituency_type
      assert previous.voter_turnouts.find_by!(voter: @asha).voted?
      assert_nil current.voter_turnouts.find_by(voter: @asha)
    end
  end

  test "export follows the filters" do
    get voters_path(format: :xlsx, village_id: @village.id)
    assert_response :success
    file = Tempfile.new([ "voters", ".xlsx" ])
    file.binmode
    file.write(@response.body)
    file.close
    sheet = Roo::Spreadsheet.open(file.path, extension: :xlsx).sheet(0)
    assert_equal "Sr no", sheet.cell(1, 1)
    assert_equal 1, sheet.last_row - 1
    assert_equal "Asha Patil", sheet.cell(2, 3)
  end
end
