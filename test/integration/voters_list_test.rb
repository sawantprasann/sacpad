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

  test "the index lists voters by booth number then serial" do
    Voter.create!(voter_id: "EARLY00001", first_name: "Early", last_name: "Row", sr_no: 1, booth: @booth, village: @village)
    Voter.create!(voter_id: "NONE000001", first_name: "No", last_name: "Booth", sr_no: 1, village: @village)

    get voters_path
    assert_response :success
    assert_match "Voters are listed by booth number, then serial number.", response.body
    assert_equal [ "Ravi Kale", "Early Row", "Asha Patil", "No Booth" ], listed_names
  end

  test "the index lists the roll and filters it" do
    get voters_path
    assert_response :success
    assert_match "ABC1234567", @response.body
    assert_match "XYZ7654321", @response.body
    assert_match "bg-green-50", @response.body
    assert_select "[data-controller=min-search-select][data-min-search-select-min-length-value='2']"
    assert_select "select[name=village_id]" do
      assert_select "option", text: "Any village"
      assert_select "option", text: "Nimgaon"
      assert_select "option", text: "Kalas"
    end

    get voters_path(voter_id: "ABC1234567", booth: "14", village_id: @village.id, sr_no: 12, name: "asha", sentiment: "pleased")
    assert_response :success
    assert_match "Asha", @response.body
    assert_no_match(/Ravi/, @response.body)
    assert_select "select[name=village_id] option[selected]", text: "Nimgaon"
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

  test "a writer can add a mobile number on the voter" do
    get voter_path(@asha)
    assert_response :success
    assert_select "h2", text: "Sentiment", count: 0
    assert_select "h2", text: "Voted"
    assert_select "form[action=?]", update_mobile_voter_path(@asha)
    assert_select "input[name=mobile][maxlength=10][pattern=?]", "[0-9]{10}"

    patch update_mobile_voter_path(@asha), params: { mobile: "98765 43210" }
    assert_redirected_to voter_path(@asha)
    assert_equal "9876543210", @asha.reload.mobile

    patch update_mobile_voter_path(@asha), params: { mobile: "123" }
    assert_redirected_to voter_path(@asha)
    assert_equal "Enter a 10-digit mobile number.", flash[:alert]
    assert_equal "9876543210", @asha.reload.mobile
  end

  test "a name search matches first and last name without the middle name" do
    Voter.create!(
      voter_id: "TJS0000001", first_name: "Tanaji", middle_name: "Jayvant", last_name: "Savant",
      sr_no: 1, booth: @booth, village: @village
    )

    get voters_path(name: "tanaji savant")
    assert_response :success
    assert_match "Tanaji", response.body
    assert_no_match(/Ravi/, response.body)
  end

  test "a booth manager only sees voters from their booth" do
    role = Role.create!(name: "Booth Manager", slug: "booth_manager")
    role.role_permissions.create!(module_name: "voter_lists", access_level: "write")
    manager = User.create!(
      organization: @org, role: role, booth: @booth, name: "Agent",
      email: "booth-agent@example.com", password: "password123"
    )
    sign_in manager

    get voters_path
    assert_response :success
    assert_match "ABC1234567", @response.body
    assert_no_match(/XYZ7654321/, @response.body)
    assert_select "select[name=booth]", count: 0
    assert_select "select[name=village_id]", count: 0
    assert_select "select[name=sentiment]", count: 0
    assert_select "input[name=voter_id]"
    assert_select "input[name=name]"
    assert_select "input[name=sr_no]"
    assert_select "select[name=voted]"

    get voter_path(@asha)
    assert_response :success
    get voter_path(@ravi)
    assert_response :not_found
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

  private

  def listed_names
    css_select("table tbody tr td:nth-child(3)").map { |cell| cell.text.squish }
  end
end
