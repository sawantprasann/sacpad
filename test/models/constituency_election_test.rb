require "test_helper"

class ConstituencyElectionTest < ActiveSupport::TestCase
  setup do
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Dharashiv", state: state, cd: "S1301")
    @loksabha = Loksabha.create!(name: "Osmanabad", state: state, district: district, constituency_no: "40")
    @assembly = @loksabha.assemblies.create!(name: "Paranda", constituency_no: "243")
    @shiv_sena = Party.create!(name: "Shiv Sena", abbreviation: "SS", color: "#ff7a18")
    @ncp = Party.create!(name: "Nationalist Congress Party", abbreviation: "NCP")
  end

  test "assembly and lok sabha can both store the same year" do
    assembly_result = store_result(@assembly, year: 2024, candidate: "Dr. Tanaji Jayawant Sawant")
    loksabha_result = store_result(@loksabha, year: 2024, candidate: "Omraje Nimbalkar")

    assert_equal @assembly, assembly_result.constituency
    assert_equal @loksabha, loksabha_result.constituency
    assert_not ConstituencyElection.column_names.include?("organization_id")
  end

  test "a constituency keeps one result per year" do
    store_result(@assembly, year: 2024, candidate: "Dr. Tanaji Jayawant Sawant")
    duplicate = @assembly.election_results.new(year: 2024, outcome: :hold)
    duplicate.candidates.build(party: @shiv_sena, candidate_name: "Someone", votes: 1, vote_percent: 1, winner: true)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:year], "is already stored for this constituency"
  end

  test "a result needs one winning candidate" do
    election = @assembly.election_results.new(year: 2019, outcome: :hold)
    assert_not election.valid?
    assert_includes election.errors[:base], "Add at least one candidate"

    election.candidates.build(party: @shiv_sena, candidate_name: "A", votes: 10, vote_percent: 40, winner: true)
    election.candidates.build(party: @ncp, candidate_name: "B", votes: 9, vote_percent: 30, winner: true)
    assert_not election.valid?
    assert_includes election.errors[:base], "Mark one winning candidate"
  end

  test "a gain records the party the seat was taken from" do
    election = store_result(@assembly, year: 2019, candidate: "Dr. Tanaji Jayawant Sawant", outcome: :gain, gained_from_party: @ncp)

    assert_equal "SS gain from NCP", election.result_label

    hold = store_result(@assembly, year: 2024, candidate: "Dr. Tanaji Jayawant Sawant")
    assert_equal "SS hold", hold.result_label
  end

  test "a new contestant does not keep a vote-share change" do
    election = @assembly.election_results.new(year: 2024, outcome: :hold, swing: -5.76)
    election.candidates.build(
      party: @ncp, candidate_name: "Rahul Maharudra Mote", votes: 101_745,
      vote_percent: 43.66, vote_change: 5, new_contestant: true, winner: false, position: 2
    )
    election.candidates.build(
      party: @shiv_sena, candidate_name: "Dr. Tanaji Jayawant Sawant", votes: 103_254,
      vote_percent: 44.31, vote_change: -5.76, winner: true, position: 1
    )

    assert election.save, election.errors.full_messages.to_sentence
    mote = election.candidates.find_by!(candidate_name: "Rahul Maharudra Mote")
    assert mote.new_contestant?
    assert_nil mote.vote_change
    assert_equal [ "Dr. Tanaji Jayawant Sawant", "Rahul Maharudra Mote" ], election.candidates.map(&:candidate_name)
  end

  test "deleting an assembly that still has a result is blocked" do
    store_result(@assembly, year: 2024, candidate: "Dr. Tanaji Jayawant Sawant")

    assert_not @assembly.destroy
    assert_includes @assembly.errors.full_messages.join, "election results"
  end

  private

  def store_result(constituency, year:, candidate:, outcome: :hold, gained_from_party: nil)
    election = constituency.election_results.new(year: year, outcome: outcome, gained_from_party: gained_from_party, swing: 1.5)
    election.candidates.build(party: @shiv_sena, candidate_name: candidate, votes: 100, vote_percent: 50, winner: true)
    election.save!
    election
  end
end
