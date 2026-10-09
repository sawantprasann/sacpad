require "test_helper"

class Eci::ImportBoothVotersTest < ActiveSupport::TestCase
  setup do
    @state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: @state, cd: "S1326")
    @loksabha = Loksabha.create!(name: "Ahmednagar", state: @state, district: district, constituency_no: "37")
    @assembly = @loksabha.assemblies.create!(name: "Ahmednagar City", constituency_no: "255")
    @village = @assembly.villages.create!(name: "Shindewadi")
    @booth = @village.booths.create!(number: "1")
  end

  test "saves voters returned by the pdf script onto the booth" do
    downloader = lambda { |_url, path|
      File.binwrite(path, "%PDF")
      :ok
    }
    extractor = lambda { |_path|
      {
        "voters" => [
          { "epic" => "ABC1234567", "name" => "Asha Ramesh Patil", "age" => "34", "house" => "12/A", "gender" => "Female" },
          { "epic" => "XYZ7654321", "name" => "Ravi Kale", "age" => "N/A", "house" => "N/A", "gender" => "" }
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
    assert_equal 34, asha.age
    assert_equal "12/A", asha.house_no
    assert_equal "Female", asha.gender
    ravi = Voter.find_by!(voter_id: "XYZ7654321")
    assert_nil ravi.age
    assert_nil ravi.house_no
    assert_nil ravi.gender
    assert_equal @state, asha.state
    assert_equal @loksabha, asha.loksabha
    assert_equal @assembly, asha.assembly
    assert_equal @village, asha.village
    assert_equal [ "Ravi", "Kale" ], [ ravi.first_name, ravi.last_name ]
  end

  test "updates an existing epic instead of inserting a second voter" do
    existing = Voter.create!(voter_id: "ABC1234567", first_name: "Old", last_name: "Name", booth: @booth)
    created_at = existing.created_at
    extractor = lambda { |_path| { "voters" => [ { "epic" => "ABC1234567", "name" => "Asha Patil" } ] } }
    downloader = lambda { |_url, path| File.binwrite(path, "%PDF"); :ok }

    assert_no_difference -> { Voter.count } do
      Eci::ImportBoothVoters.new(@booth, downloader: downloader, extractor: extractor).call
    end
    voter = Voter.find_by!(voter_id: "ABC1234567")
    assert_equal "Asha", voter.first_name
    assert_equal created_at, voter.created_at
  end

  test "writes a booth's voters in one upsert and keeps names encrypted" do
    downloader = lambda { |_url, path| File.binwrite(path, "%PDF"); :ok }
    extractor = lambda { |_path|
      { "voters" => [
        { "epic" => "ABC1234567", "name" => "Asha Patil" },
        { "epic" => "ABC1234567", "name" => "Asha Patil" },
        { "epic" => "XYZ7654321", "name" => "Ravi Kale" }
      ] }
    }

    queries = sql_queries do
      assert_equal 2, Eci::ImportBoothVoters.new(@booth, downloader: downloader, extractor: extractor).call
    end

    assert_equal 1, queries.count { |sql| sql.match?(/INSERT INTO "voters"/i) }
    raw = Voter.connection.select_value("SELECT first_name FROM voters WHERE id = #{Voter.find_by!(voter_id: "ABC1234567").id}")
    assert_not_equal "Asha", raw
  end

  test "stores the roll cover on the booth and links the taluka" do
    downloader = lambda { |_url, path| File.binwrite(path, "%PDF"); :ok }
    extractor = lambda { |_path|
      {
        "cover" => {
          "Polling Station No. and Name" => "1 - Zilla Parishad School",
          "Polling Station Address" => "Nagathali, Paranda",
          "Type of Polling Station" => "Rural",
          "Police Station" => "Paranda",
          "Pin Code" => "413502",
          "Taluka" => "Paranda",
          "Main Town or Village" => "Nagathali"
        },
        "voters" => []
      }
    }

    Eci::ImportBoothVoters.new(@booth, downloader: downloader, extractor: extractor).call
    @booth.reload

    assert_equal "1 - Zilla Parishad School", @booth.name
    assert_equal "Nagathali, Paranda", @booth.address
    assert_equal "Rural", @booth.station_type
    assert_equal "Nagathali", @booth.village.name
    assert_nil @assembly.villages.find_by(name: "Shindewadi")
    @village = @booth.village
    assert_equal "Paranda", @village.police_station
    assert_equal "413502", @village.pin_code
    assert_equal "Paranda", @village.taluka.name
    assert_equal @loksabha.district, @village.taluka.district
  end

  test "skips a booth whose english roll pdf is not published" do
    downloader = lambda { |_url, _path| :missing }
    extractor = lambda { |_path| flunk "extract should not run" }

    assert_equal 0, Eci::ImportBoothVoters.new(@booth, downloader: downloader, extractor: extractor).call
    assert_equal 0, Voter.count
  end

  test "reports the script error instead of the bottom backtrace frame" do
    message = Eci::ImportBoothVoters.script_failure(<<~ERR)
      cannot load such file -- pdf-reader (LoadError)
      \tfrom <internal:gem_prelude>:2:in `<internal:gem_prelude>'
    ERR

    assert_equal "cannot load such file -- pdf-reader (LoadError)", message
  end

  test "the extract script ships inside the application" do
    assert Eci::ImportBoothVoters::SCRIPT.start_with?(Rails.root.to_s)
    assert File.file?(Eci::ImportBoothVoters::SCRIPT)
    assert File.file?(Rails.root.join("script/eroll/ocr_page.swift"))
  end

  test "reads state, lok sabha, assembly, and village once for the whole booth" do
    other = @village.booths.create!(number: "2")
    booths = Booth.includes(village: { assembly: { loksabha: [ :state, :district ] } }).where(id: [ @booth.id, other.id ]).to_a
    downloader = lambda { |_url, _path| :missing }

    queries = select_queries do
      booths.each do |booth|
        Eci::ImportBoothVoters.new(booth, downloader: downloader, extractor: ->(_) { flunk "extract should not run" }).call
      end
    end

    assert_empty queries.grep(/FROM "(villages|assemblies|loksabhas|states)"/)
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

  private

  def select_queries(&block)
    sql_queries(&block).grep(/\ASELECT/i)
  end

  def sql_queries
    queries = []
    callback = lambda { |*, payload|
      sql = payload[:sql].to_s
      queries << sql if payload[:name] != "SCHEMA"
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
