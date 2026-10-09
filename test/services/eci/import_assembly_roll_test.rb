require "test_helper"

class Eci::ImportAssemblyRollTest < ActiveSupport::TestCase
  setup do
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Satara", state: state, cd: "S1331")
    loksabha = Loksabha.create!(name: "Madha", state: state, district: district, constituency_no: "43")
    @assembly = loksabha.assemblies.create!(name: "Phaltan (SC)", constituency_no: "255", first_part: 1, last_part: 3)
    @assembly.villages.create!(name: "Shirsuphal").booths.create!(number: "1")
  end

  test "files each published part under the village named on its pdf" do
    published = { 1 => "Phaltan", 2 => "Phaltan", 3 => "Adarki" }
    requested = nil
    downloader = lambda { |url, path|
      requested = url[/ENG-(\d+)-WI/, 1].to_i
      return :missing unless published.key?(requested)

      File.binwrite(path, "%PDF")
      :ok
    }
    extractor = lambda { |_path|
      { "cover" => { "Main Town or Village" => published[requested], "Police Station" => "Phaltan" }, "voters" => [] }
    }

    Eci::ImportAssemblyRoll.new(@assembly, downloader: downloader, extractor: extractor).call

    phaltan = @assembly.villages.find_by!(name: "Phaltan")
    assert_equal %w[1 2], phaltan.booths.order(:number).pluck(:number)
    assert_equal "Phaltan", phaltan.police_station
    assert_equal [ "3" ], @assembly.villages.find_by!(name: "Adarki").booths.pluck(:number)
    assert_nil @assembly.villages.find_by(name: "Shirsuphal")
  end
end
