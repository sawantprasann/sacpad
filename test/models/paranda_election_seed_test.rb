require "test_helper"

class ParandaElectionSeedTest < ActiveSupport::TestCase
  test "loads the 2024 and 2019 Paranda results once" do
    ParandaElectionSeed.load!
    ParandaElectionSeed.load!

    assembly = Assembly.find_by!(name: "Paranda", constituency_no: "243")
    results = assembly.election_results.order(year: :desc)

    assert_equal [ 2024, 2019 ], results.map(&:year)
    assert_equal "SS hold", results.first.result_label
    assert_equal "SS gain from NCP", results.second.result_label
    assert_equal 6, results.first.candidates.count
    assert_equal 4, results.second.candidates.count
    assert_equal "Dr. Tanaji Jayawant Sawant", results.first.winning_candidate.candidate_name
    assert_equal 103_254, results.first.winning_candidate.votes
    assert results.first.candidates.find_by!(candidate_name: "Rahul Maharudra Mote").new_contestant?
  end
end
