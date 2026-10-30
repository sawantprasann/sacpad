require "test_helper"

class NativeScriptTest < ActiveSupport::TestCase
  test "english village names become the Lok Sabha script" do
    assert_equal "वाघोलि", NativeScript.transliterate("Wagholi", "mr")
    assert_nil NativeScript.transliterate("Wagholi", "ta")
    assert_nil NativeScript.transliterate("Wagholi", "kn")
  end

  test "a blank locale or an unchanged word stores nothing" do
    assert_nil NativeScript.transliterate("Wagholi", nil)
    assert_nil NativeScript.transliterate("", "mr")
  end

  test "saving a village fills the native name and keeps a hand correction" do
    state = State.create!(name: "Script State")
    district = District.create!(name: "Script District", state: state)
    loksabha = Loksabha.create!(name: "Baramati", state: state, district: district, native_locale: "mr")
    assembly = Assembly.create!(name: "Baramati", loksabha: loksabha)
    village = Village.create!(name: "Wagholi", assembly: assembly)

    assert_equal "वाघोलि", village.native_name
    assert_equal "बारामाति", loksabha.native_name

    village.update!(native_name: "वाघोली")
    village.update!(police_station: "Wagholi")
    assert_equal "वाघोली", village.reload.native_name

    I18n.with_locale(:mr) { assert_equal "वाघोली", village.display_name }
    assert_equal "Wagholi", village.display_name
  end

  test "a voter name is transliterated part by part" do
    state = State.create!(name: "Voter Script State")
    loksabha = Loksabha.create!(name: "Pune", state: state, native_locale: "mr")
    voter = Voter.create!(
      first_name: "Tanaji",
      middle_name: "Jayvant",
      last_name: "Savant",
      loksabha: loksabha
    )

    assert_equal "तानाजि", voter.native_first_name
    assert_equal "जायवानत", voter.native_middle_name
    assert_equal "सावानत", voter.native_last_name

    I18n.with_locale(:mr) { assert_equal "तानाजि जायवानत सावानत", voter.display_name }
    assert voter.matches_name?("तानाजि")
    assert voter.matches_name?("Tanaji")

    voter.update!(native_first_name: "तानाजी", first_name: "Tanaji")
    assert_equal "तानाजी", voter.reload.native_first_name
  end
end
