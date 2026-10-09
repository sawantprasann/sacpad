require "test_helper"

class Eci::ImportLoksabhaTest < ActiveSupport::TestCase
  class FakeClient
    def districts(_state_cd)
      [ { "districtNo" => "26", "districtCd" => "S1326" } ]
    end

    def assemblies(district_cd)
      return [] if district_cd == "26"

      if district_cd == "S1326"
        [ { "asmblyNo" => 225, "asmblyName" => "Ahmednagar City", "pcNo" => "02" } ]
      else
        [
          { "asmblyNo" => 8, "asmblyName" => "Arabhavi", "pcNo" => "2" },
          { "asmblyNo" => 9, "asmblyName" => "Other", "pcNo" => "3" }
        ]
      end
    end
  end

  setup do
    @state = State.create!(name: "Karnataka", cd: "S10")
    @district = District.create!(name: "Belagavi", state: @state, cd: "S1001")
    @loksabha = Loksabha.create!(name: "Belagavi", state: @state, district: @district, constituency_no: "2")
  end

  test "imports assemblies for this lok sabha" do
    result = Eci::ImportLoksabha.new(@loksabha, client: FakeClient.new).call

    assert_equal 1, result.assemblies
    assert_equal "Fetched 1 assembly for Belagavi. Roll PDFs are queued for assemblies with a first and last part.", result.summary("Belagavi")
    assert_equal "Arabhavi", @loksabha.assemblies.find_by!(constituency_no: "8").name
    assert_nil @loksabha.assemblies.find_by(constituency_no: "9")
    assert_equal 0, Village.count
  end

  test "matches a zero-padded constituency number and a short district code" do
    maharashtra = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: maharashtra, cd: "S1326")
    loksabha = Loksabha.create!(name: "Ahmednagar", state: maharashtra, district: district, constituency_no: "2")

    Eci::ImportLoksabha.new(loksabha, client: FakeClient.new).call
    assert loksabha.assemblies.exists?(name: "Ahmednagar City", constituency_no: "225")

    short = District.create!(name: "Ahmednagar number", state: maharashtra, cd: "26")
    numbered = Loksabha.create!(name: "Ahmednagar numbered", state: maharashtra, district: short, constituency_no: "2")
    Eci::ImportLoksabha.new(numbered, client: FakeClient.new).call
    assert numbered.assemblies.exists?(constituency_no: "225")
  end

  test "running the fetch again does not duplicate assemblies" do
    importer = Eci::ImportLoksabha.new(@loksabha, client: FakeClient.new)
    importer.call
    importer.call

    assert_equal 1, @loksabha.assemblies.count
  end

  test "asks for the district code before calling the commission" do
    @loksabha.update!(district: nil)

    error = assert_raises(Eci::ImportLoksabha::Error) do
      Eci::ImportLoksabha.new(@loksabha, client: FakeClient.new).call
    end
    assert_match "district", error.message
    assert_equal 0, Assembly.count
  end
end
