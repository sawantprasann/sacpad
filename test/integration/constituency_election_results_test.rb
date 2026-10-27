require "test_helper"

class ConstituencyElectionResultsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "results-admin@example.com", password: "password123", tier: :full)
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Dharashiv", state: state, cd: "S1302")
    @loksabha = Loksabha.create!(name: "Osmanabad", state: state, district: district, constituency_no: "40")
    @assembly = @loksabha.assemblies.create!(name: "Paranda", constituency_no: "243")
    @shiv_sena = Party.create!(name: "Shiv Sena", abbreviation: "SS", color: "#ff7a18")
    @ncp = Party.create!(name: "NCP-SP", abbreviation: "NCP-SP", color: "#1d4ed8")
    Role.seed_system_roles!
  end

  test "an admin stores an assembly result and sees the published table" do
    sign_in @admin
    get console_loksabha_assembly_path(@loksabha, @assembly)
    assert_response :success
    assert_select "a", text: "New election result"

    assert_difference -> { @assembly.election_results.count }, 1 do
      post console_loksabha_assembly_constituency_elections_path(@loksabha, @assembly), params: paranda_2024_params
    end

    election = @assembly.election_results.find_by!(year: 2024)
    assert_redirected_to console_loksabha_assembly_constituency_election_path(@loksabha, @assembly, election)
    follow_redirect!
    assert_match "Dr. Tanaji Jayawant Sawant", response.body
    assert_match "103,254", response.body
    assert_match "SS hold", response.body
    assert_match "New", response.body
    assert_equal 2, election.candidates.count
  end

  test "an admin can store a lok sabha result on the same year" do
    sign_in @admin

    assert_difference -> { @loksabha.election_results.count }, 1 do
      post console_loksabha_constituency_elections_path(@loksabha), params: {
        constituency_election: {
          year: 2024,
          outcome: "hold",
          title: "2024 Lok Sabha election : Osmanabad",
          candidates_attributes: {
            "0" => candidate_row(@shiv_sena, "Omraje Nimbalkar", votes: 500, percent: "55.00", winner: "1")
          }
        }
      }
    end

    election = @loksabha.election_results.find_by!(year: 2024)
    assert_redirected_to console_loksabha_constituency_election_path(@loksabha, election)
  end

  test "a missing winner stays on the form" do
    sign_in @admin

    assert_no_difference -> { ConstituencyElection.count } do
      post console_loksabha_assembly_constituency_elections_path(@loksabha, @assembly), params: {
        constituency_election: {
          year: 2024,
          outcome: "hold",
          candidates_attributes: {
            "0" => candidate_row(@shiv_sena, "Dr. Tanaji Jayawant Sawant", votes: 10, percent: "50", winner: "0")
          }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Mark one winning candidate", response.body
  end

  test "the organization dashboard shows the constituency it is assigned to" do
    assembly_result = store_paranda!
    loksabha_result = @loksabha.election_results.new(
      year: 2024, outcome: :hold, title: "2024 Lok Sabha election : Osmanabad", swing: 2
    )
    loksabha_result.candidates.build(
      party: @shiv_sena, candidate_name: "Omraje Nimbalkar", votes: 500, vote_percent: 55, winner: true
    )
    loksabha_result.save!

    assembly_org = ActsAsTenant.without_tenant { Organization.create!(name: "Paranda office", constituency: @assembly) }
    loksabha_org = ActsAsTenant.without_tenant { Organization.create!(name: "Osmanabad office", constituency: @loksabha) }
    role = Role.find_by!(slug: "karyakarta")

    sign_in User.create!(organization: assembly_org, role: role, name: "Field", email: "field@example.com", password: "password123")
    get "/"
    assert_match "Election result", response.body
    assert_match "held the seat by 1,509 votes", response.body
    assert_match "Dr. Tanaji Jayawant Sawant", response.body
    assert_select "a[href='#{election_result_path}']", text: "View election result"
    assert_no_match "Omraje Nimbalkar", response.body
    assert_no_match "Margin of victory", response.body

    get election_result_path
    assert_match "Vote share", response.body
    assert_match "Margin of victory", response.body
    assert_match "Dr. Tanaji Jayawant Sawant", response.body
    assert_no_match "Omraje Nimbalkar", response.body

    sign_out :user
    sign_in User.create!(organization: loksabha_org, role: role, name: "Lok Sabha", email: "ls@example.com", password: "password123")
    get "/"
    assert_match "Omraje Nimbalkar", response.body
    assert_no_match "Dr. Tanaji Jayawant Sawant", response.body

    get election_result_path(election_year: assembly_result.year)
    assert_match "Omraje Nimbalkar", response.body
    assert_no_match "Dr. Tanaji Jayawant Sawant", response.body
  end

  test "an older year is available on the same organization dashboard" do
    store_paranda!
    older = @assembly.election_results.new(
      year: 2019, outcome: :gain, gained_from_party: @ncp, swing: 9.99, title: "2019 Assembly election : Paranda"
    )
    older.candidates.build(
      party: @shiv_sena, candidate_name: "Earlier winner", votes: 106_674, vote_percent: 50.07, winner: true, position: 1
    )
    older.save!

    org = ActsAsTenant.without_tenant { Organization.create!(name: "Paranda office", constituency: @assembly) }
    role = Role.find_by!(slug: "org_admin")
    sign_in User.create!(organization: org, role: role, name: "Admin", email: "org-admin@example.com", password: "password123")

    get "/"
    assert_match "Dr. Tanaji Jayawant Sawant", response.body
    assert_no_match "Earlier winner", response.body
    assert_select "a[href='#{election_result_path}']", text: "View election result"
    assert_select "turbo-frame#election-result", count: 0

    get election_result_path
    assert_match "Dr. Tanaji Jayawant Sawant", response.body
    assert_no_match "Earlier winner", response.body
    assert_select "turbo-frame#election-result a[href='#{election_result_path(election_year: 2019)}']" do |links|
      assert_equal "election-result", links.first["data-turbo-frame"]
      assert_nil links.first["data-turbo-action"]
    end
    assert_select "turbo-frame#election-result span[aria-disabled='true']", text: "2024"
    assert_select "a[href='#{election_result_path(election_year: 2024)}']", count: 0
    assert_select "#election-share-#{@assembly.election_results.find_by!(year: 2024).id}"

    get election_result_path(election_year: 2019)
    assert_match "Earlier winner", response.body
    assert_match "took the seat from NCP-SP", response.body
    assert_match "SS gain from NCP-SP", response.body
    assert_no_match "Dr. Tanaji Jayawant Sawant", response.body
    assert_select "turbo-frame#election-result a[href='#{election_result_path(election_year: 2024)}']" do |links|
      assert_equal "election-result", links.first["data-turbo-frame"]
      assert_nil links.first["data-turbo-action"]
    end
    assert_select "turbo-frame#election-result span[aria-disabled='true']", text: "2019"
    assert_select "a[href='#{election_result_path(election_year: 2019)}']", count: 0
  end

  private

  def store_paranda!
    election = @assembly.election_results.new(
      year: 2024,
      outcome: :hold,
      swing: -5.76,
      margin_votes: 1509,
      margin_percent: 0.65,
      turnout_votes: 233_715,
      turnout_percent: 70.49,
      valid_votes: 233_027,
      registered_electors: 331_546,
      title: "2024 Maharashtra Legislative Assembly election : Paranda"
    )
    election.candidates.build(
      party: @shiv_sena, candidate_name: "Dr. Tanaji Jayawant Sawant",
      votes: 103_254, vote_percent: 44.31, vote_change: -5.76, winner: true, position: 1
    )
    election.candidates.build(
      party: @ncp, candidate_name: "Rahul Maharudra Mote",
      votes: 101_745, vote_percent: 43.66, new_contestant: true, winner: false, position: 2
    )
    election.save!
    election
  end

  def paranda_2024_params
    {
      constituency_election: {
        year: 2024,
        title: "2024 Maharashtra Legislative Assembly election : Paranda",
        outcome: "hold",
        swing: "-5.76",
        margin_votes: 1509,
        margin_percent: "0.65",
        margin_change: "-14.79",
        turnout_votes: 233_715,
        turnout_percent: "70.49",
        turnout_change: "2.18",
        valid_votes: 233_027,
        registered_electors: 331_546,
        electors_change: "5.35",
        candidates_attributes: {
          "0" => candidate_row(@shiv_sena, "Dr. Tanaji Jayawant Sawant", votes: 103_254, percent: "44.31", change: "-5.76", winner: "1", position: 1),
          "1" => candidate_row(@ncp, "Rahul Maharudra Mote", votes: 101_745, percent: "43.66", fresh: "1", winner: "0", position: 2)
        }
      }
    }
  end

  def candidate_row(party, name, votes:, percent:, winner:, change: nil, fresh: "0", position: nil)
    {
      party_id: party.id,
      candidate_name: name,
      votes: votes,
      vote_percent: percent,
      vote_change: change,
      new_contestant: fresh,
      winner: winner,
      position: position
    }
  end
end
