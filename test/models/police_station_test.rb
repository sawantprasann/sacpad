require "test_helper"

class PoliceStationTest < ActiveSupport::TestCase
  setup do
    @state = State.create!(name: "Maharashtra")
    @loksabha = Loksabha.create!(name: "Baramati", state: @state, native_locale: "mr")
    @assembly = @loksabha.assemblies.create!(name: "Indapur")
  end

  test "villages in one state share a police station and store its native name" do
    first = @assembly.villages.create!(name: "Nimgaon", police_station: "Paranda")
    second = @assembly.villages.create!(name: "Kalas", police_station: " paranda ")

    assert_equal first.police_station_id, second.police_station_id
    assert_equal "Paranda", second.police_station
    assert_equal "Paranda", second.police_station_record.name
    assert_equal NativeScript.transliterate("Paranda", "mr"), first.police_station_record.native_name
    assert_equal 1, @state.police_stations.count
  end

  test "the same police station name in another state is a different record" do
    karnataka = State.create!(name: "Karnataka")
    other_assembly = Loksabha.create!(name: "Bengaluru", state: karnataka, native_locale: "mr")
      .assemblies.create!(name: "Yeshwanthpur")

    maharashtra_village = @assembly.villages.create!(name: "Nimgaon", police_station: "City")
    karnataka_village = other_assembly.villages.create!(name: "Nimgaon", police_station: "City")

    assert_not_equal maharashtra_village.police_station_id, karnataka_village.police_station_id
    assert_equal NativeScript.transliterate("City", "mr"), karnataka_village.police_station_record.native_name
  end

  test "a blank police station clears the foreign key and keeps the station record" do
    village = @assembly.villages.create!(name: "Nimgaon", police_station: "Paranda")
    station = village.police_station_record

    village.update!(police_station: "  ")

    assert_nil village.police_station
    assert_nil village.police_station_id
    assert station.reload.persisted?
  end

  test "marathi shows the police station native name" do
    village = @assembly.villages.create!(name: "Nimgaon", police_station: "Paranda")
    village.police_station_record.update!(native_name: "परंडा")

    assert_equal "Paranda", village.police_station_display_name
    I18n.with_locale(:mr) { assert_equal "परंडा", village.reload.police_station_display_name }
  end

  test "a hand-corrected native name is kept" do
    village = @assembly.villages.create!(name: "Nimgaon", police_station: "Paranda")
    station = village.police_station_record

    station.update!(native_name: "परंडा")
    village.update!(pin_code: "413502")

    assert_equal "परंडा", station.reload.native_name
  end

  test "a police station with villages cannot be deleted" do
    village = @assembly.villages.create!(name: "Nimgaon", police_station: "Paranda")

    assert_not village.police_station_record.destroy
  end

  test "native name stays blank when the state has more than one Lok Sabha language" do
    other = Loksabha.create!(name: "Pune", state: @state, native_locale: "mr")
    other.update_column(:native_locale, "ta")
    village = @assembly.villages.create!(name: "Nimgaon", police_station: "Paranda")

    assert_nil village.police_station_record.native_name
  end
end
