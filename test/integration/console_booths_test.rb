require "test_helper"

class ConsoleBoothsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "booth-admin@example.com", password: "password123", tier: :full)
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: state, cd: "S1326")
    loksabha = Loksabha.create!(name: "Ahmednagar", state: state, district: district, constituency_no: "37")
    assembly = loksabha.assemblies.create!(name: "Paranda", constituency_no: "244")
    village = assembly.villages.create!(name: "Nagathali")
    @booth = village.booths.create!(number: "2")
    other = village.booths.create!(number: "3")
    Voter.create!(
      voter_id: "BBB2222222", first_name: "Ravi", middle_name: "S", last_name: "Kale",
      age: 34, gender: "Male", house_no: "12", booth: @booth, village: village
    )
    Voter.create!(
      voter_id: "AAA1111111", first_name: "Asha", last_name: "Patil",
      age: 40, gender: "Female", house_no: "4", booth: @booth, village: village
    )
    Voter.create!(
      voter_id: "CCC3333333", first_name: "Other", last_name: "Booth",
      booth: other, village: village
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

  test "booth voter filters keep only the matching rows" do
    sign_in @admin
    get console_booth_path(@booth, name: "Asha", gender: "Female")

    assert_response :success
    assert_match "Asha", response.body
    assert_no_match "Ravi", response.body
  end
end
