require "test_helper"

class Eci::ImportBoothVotersTest < ActiveSupport::TestCase
  setup do
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: state, cd: "S1326")
    loksabha = Loksabha.create!(name: "Ahmednagar", state: state, district: district, constituency_no: "37")
    assembly = loksabha.assemblies.create!(name: "Ahmednagar City", constituency_no: "255")
    village = assembly.villages.create!(name: "Shindewadi")
    @booth = village.booths.create!(number: "1")
  end

  test "saves voters returned by the pdf script onto the booth" do
    downloader = lambda { |_url, path|
      File.binwrite(path, "%PDF")
      :ok
    }
    extractor = lambda { |_path|
      {
        "voters" => [
          { "epic" => "ABC1234567", "name" => "Asha Ramesh Patil" },
          { "epic" => "XYZ7654321", "name" => "Ravi Kale" }
        ]
      }
    }

    saved = Eci::ImportBoothVoters.new(@booth, downloader: downloader, extractor: extractor).call

    assert_equal 2, saved
    asha = Voter.find_by!(voter_id: "ABC1234567")
    assert_equal @booth, asha.booth
    assert_equal "Asha", asha.first_name
    assert_equal "Ramesh", asha.middle_name
    assert_equal "Patil", asha.last_name
    assert_equal "Maharashtra", asha.state
    assert_equal "Ahmednagar", asha.loksabha
    assert_equal "Ahmednagar City", asha.assembly
    assert_equal "Shindewadi", asha.village
    assert_equal [ "Ravi", "Kale" ], Voter.find_by!(voter_id: "XYZ7654321").then { |voter| [ voter.first_name, voter.last_name ] }
  end

  test "updates an existing epic instead of inserting a second voter" do
    Voter.create!(voter_id: "ABC1234567", first_name: "Old", last_name: "Name", booth: @booth)
    extractor = lambda { |_path| { "voters" => [ { "epic" => "ABC1234567", "name" => "Asha Patil" } ] } }
    downloader = lambda { |_url, path| File.binwrite(path, "%PDF"); :ok }

    assert_no_difference -> { Voter.count } do
      Eci::ImportBoothVoters.new(@booth, downloader: downloader, extractor: extractor).call
    end
    assert_equal "Asha", Voter.find_by!(voter_id: "ABC1234567").first_name
  end

  test "skips a booth whose english roll pdf is not published" do
    downloader = lambda { |_url, _path| :missing }
    extractor = lambda { |_path| flunk "extract should not run" }

    assert_equal 0, Eci::ImportBoothVoters.new(@booth, downloader: downloader, extractor: extractor).call
    assert_equal 0, Voter.count
  end

  test "asks the script for the english draft-roll pdf of this assembly and part" do
    seen = nil
    downloader = lambda { |url, path|
      seen = url
      File.binwrite(path, "%PDF")
      :missing
    }

    Eci::ImportBoothVoters.new(@booth, downloader: downloader, extractor: ->(_) { {} }).call

    assert_equal(
      "https://voters.eci.gov.in/eroll/2026/s13/sir-draftroll/255/2026-EROLLGEN-S13-255-SIR-DraftRoll-Revision1-ENG-1-WI.pdf",
      seen
    )
  end
end
