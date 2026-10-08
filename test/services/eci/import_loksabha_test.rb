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

    def parts(_state_cd, ac_number)
      case ac_number.to_i
      when 8
        [
          { "partNumber" => 1, "partName" => "Government Lower Primary School, Gadlegaon" },
          { "partNumber" => 2, "partName" => "Government Lower Primary School, Gadlegaon" },
          { "partNumber" => 3, "partName" => "Government Higher Primary School, Thoogaon" }
        ]
      when 225
        [
          { "partNumber" => 1, "partName" => "Shindewadi" },
          { "partNumber" => 2, "partName" => "Shindewadi" },
          { "partNumber" => 3, "partName" => "Kurbavi" }
        ]
      else
        []
      end
    end
  end

  setup do
    @state = State.create!(name: "Karnataka", cd: "S10")
    @district = District.create!(name: "Belagavi", state: @state, cd: "S1001")
    @loksabha = Loksabha.create!(name: "Belagavi", state: @state, district: @district, constituency_no: "2")
  end

  test "imports assemblies for this lok sabha and groups booths into villages" do
    result = Eci::ImportLoksabha.new(@loksabha, client: FakeClient.new).call

    assert_equal 1, result.assemblies
    assert_equal 2, result.villages
    assert_equal 3, result.booths
    assert_equal "Fetched 1 assembly, 2 villages, and 3 booths for Belagavi.", result.summary("Belagavi")

    assembly = @loksabha.assemblies.find_by!(constituency_no: "8")
    assert_equal "Arabhavi", assembly.name
    assert_equal %w[1 2], assembly.villages.find_by!(name: "Gadlegaon").booths.order(:number).pluck(:number)
    assert_equal [ "3" ], assembly.villages.find_by!(name: "Thoogaon").booths.pluck(:number)
    assert_nil @loksabha.assemblies.find_by(constituency_no: "9")
  end

  test "treats a bare part name as the village and matches a zero-padded constituency number" do
    maharashtra = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: maharashtra, cd: "S1326")
    loksabha = Loksabha.create!(name: "Ahmednagar", state: maharashtra, district: district, constituency_no: "2")

    result = Eci::ImportLoksabha.new(loksabha, client: FakeClient.new).call

    assembly = loksabha.assemblies.find_by!(constituency_no: "225")
    short = District.create!(name: "Ahmednagar number", state: maharashtra, cd: "26")
    numbered = Loksabha.create!(name: "Ahmednagar numbered", state: maharashtra, district: short, constituency_no: "2")
    Eci::ImportLoksabha.new(numbered, client: FakeClient.new).call
    assert numbered.assemblies.exists?(constituency_no: "225")
    assert_equal 2, result.villages
    assert_equal 3, result.booths
    assert_equal %w[1 2], assembly.villages.find_by!(name: "Shindewadi").booths.order(:number).pluck(:number)
  end

  test "running the fetch again does not duplicate rows" do
    importer = Eci::ImportLoksabha.new(@loksabha, client: FakeClient.new)
    importer.call
    importer.call

    assert_equal 1, @loksabha.assemblies.count
    assert_equal 2, Village.joins(:assembly).where(assemblies: { loksabha_id: @loksabha.id }).count
    assert_equal 3, Booth.joins(village: :assembly).where(assemblies: { loksabha_id: @loksabha.id }).count
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
