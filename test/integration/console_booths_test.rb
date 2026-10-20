require "test_helper"

class ConsoleBoothsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "booth-admin@example.com", password: "password123", tier: :full)
    state = State.create!(name: "Maharashtra", cd: "S13")
    @district = District.create!(name: "Ahmednagar", state: state, cd: "S1326")
    @taluka = @district.talukas.create!(name: "Paranda Taluka")
    loksabha = Loksabha.create!(name: "Ahmednagar", state: state, district: @district, constituency_no: "37")
    assembly = loksabha.assemblies.create!(name: "Paranda", constituency_no: "244")
    @village = assembly.villages.create!(name: "Nagathali", taluka: @taluka)
    @booth = @village.booths.create!(number: "2")
    other = @village.booths.create!(number: "3")
    Voter.create!(
      voter_id: "BBB2222222", first_name: "Ravi", middle_name: "S", last_name: "Kale",
      age: 34, gender: "Male", house_no: "12", booth: @booth, village: @village
    )
    Voter.create!(
      voter_id: "AAA1111111", first_name: "Asha", last_name: "Patil",
      age: 40, gender: "Female", house_no: "4", booth: @booth, village: @village
    )
    Voter.create!(
      voter_id: "CCC3333333", first_name: "Other", last_name: "Booth",
      booth: other, village: @village
    )
  end

  test "a booth details page lists only that booth's voters" do
    sign_in @admin
    get console_booth_path(@booth)

    assert_response :success
    assert_match "Ravi", response.body
    assert_match "BBB2222222", response.body
    assert_match "12", response.body
    assert_match "Asha", response.body
    assert_no_match "CCC3333333", response.body
  end

  test "booth pages have no edit or delete actions" do
    sign_in @admin
    get console_booths_path

    assert_response :success
    assert_select "a[aria-label=Edit]", count: 0
    assert_select "button[aria-label=Delete]", count: 0

    get console_booth_path(@booth)

    assert_response :success
    assert_select "a", text: "Edit Booth", count: 0
    assert_select "button", text: "Delete Booth", count: 0
  end

  test "booth index filters by number, village, taluka, and district" do
    other_district = District.create!(name: "Pune", state: @district.state, cd: "S1325")
    other_taluka = other_district.talukas.create!(name: "Haveli")
    other_village = @village.assembly.villages.create!(name: "Wagholi", taluka: other_taluka)
    other_village.booths.create!(number: "9")
    sign_in @admin

    get console_booths_path
    assert_select "select[name=district_id] option", text: "Ahmednagar"
    assert_select "select[name=taluka_id] option[data-district-id='#{@taluka.district_id}']", text: "Paranda Taluka"
    assert_select "select[name=village_id] option[data-taluka-id='#{@village.taluka_id}'][data-district-id='#{@district.id}']", text: "Nagathali"

    get console_booths_path(booth_number: "2")
    assert_select "tbody a", text: "2"
    assert_select "tbody a", text: "9", count: 0

    get console_booths_path(village_id: @village.id)
    assert_select "tbody a", text: "2"
    assert_select "tbody a", text: "3"
    assert_select "tbody a", text: "9", count: 0

    get console_booths_path(taluka_id: @taluka.id)
    assert_select "tbody a", text: "2"
    assert_select "tbody a", text: "9", count: 0

    get console_booths_path(district_id: other_district.id)
    assert_select "tbody a", text: "9"
    assert_select "tbody a", text: "2", count: 0
  end

  test "booth page compares roll elector counts with voters on file" do
    @booth.update!(male_electors: 5, female_electors: 1, other_electors: 2)
    sign_in @admin
    get console_booth_path(@booth)

    assert_response :success
    assert_select "h2", text: "From the roll"
    assert_select "h2", text: "Voters on file"
    assert_select "p", text: "Does not match the roll", count: 2
  end

  test "booth voter filters keep only the matching rows" do
    sign_in @admin
    get console_booth_path(@booth, name: "Asha", gender: "Female")

    assert_response :success
    assert_match "Asha", response.body
    assert_no_match "Ravi", response.body
  end
end
