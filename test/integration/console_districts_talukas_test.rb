require "test_helper"

class ConsoleDistrictsTalukasTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "geo-admin@example.com", password: "password123", tier: :full)
    @state = State.create!(name: "Maharashtra", cd: "S13")
    @other_state = State.create!(name: "Karnataka", cd: "S10")
    @district = District.create!(name: "Ahmednagar", state: @state, cd: "S1326")
    @other_district = District.create!(name: "Belagavi", state: @other_state, cd: "S1002")
    @taluka = @district.talukas.create!(name: "Paranda")
    @other_taluka = @district.talukas.create!(name: "Shrigonda")
    @loksabha = Loksabha.create!(name: "Ahmednagar", state: @state, district: @district, constituency_no: "37")
    assembly = @loksabha.assemblies.create!(name: "Paranda", constituency_no: "244")
    @village = assembly.villages.create!(name: "Nagathali", taluka: @taluka, police_station: "Paranda PS", pin_code: "413502")
    assembly.villages.create!(name: "Shindewadi", taluka: @taluka, pin_code: "413501")
    sign_in @admin
  end

  test "district and taluka lists open a show page and have no delete action" do
    get console_districts_path

    assert_response :success
    assert_select "select[name=state_id] option", text: "Maharashtra"
    assert_select "input[name=state]", count: 0
    assert_select "a[href='#{console_district_path(@district)}']", text: "Ahmednagar"
    assert_select "form[action='#{console_district_path(@district)}']", count: 0
    assert_select "button[aria-label=Delete]", count: 0

    get console_district_path(@district)
    assert_response :success
    assert_select "select[name=taluka_id] option", text: "Paranda"
    assert_select "a[href='#{console_taluka_path(@taluka)}']", text: "Paranda"
    assert_select "a[href='#{console_loksabha_path(@loksabha)}']", text: "Ahmednagar"
    assert_select "button[aria-label=Delete]", count: 0

    get console_talukas_path
    assert_response :success
    assert_select "select[name=district_id] option", text: "Ahmednagar"
    assert_select "input[name=district]", count: 0
    assert_select "a[href='#{console_taluka_path(@taluka)}']", text: "Paranda"
    assert_select "button[aria-label=Delete]", count: 0

    get console_taluka_path(@taluka)
    assert_response :success
    assert_select "select[name=village_id] option", text: "Nagathali"
    assert_select "input[name=village]", count: 0
    assert_match "Paranda PS", response.body
    assert_select "form[action='#{console_taluka_path(@taluka)}'] input[name=_method][value=delete]", count: 0
  end

  test "geography filters are dropdowns and keep only the matching rows" do
    get console_districts_path(state_id: @other_state.id)
    assert_select "a", text: "Belagavi"
    assert_select "a[href='#{console_district_path(@district)}']", count: 0

    get console_district_path(@district, taluka_id: @other_taluka.id)
    assert_select "a[href='#{console_taluka_path(@other_taluka)}']", text: "Shrigonda"
    assert_select "a[href='#{console_taluka_path(@taluka)}']", count: 0

    get console_talukas_path(district_id: @district.id, name: "Shri")
    assert_select "a[href='#{console_taluka_path(@other_taluka)}']", text: "Shrigonda"
    assert_select "a[href='#{console_taluka_path(@taluka)}']", count: 0

    get console_taluka_path(@taluka, village_id: @village.id)
    assert_select "tbody a", text: "Nagathali"
    assert_select "tbody a", text: "Shindewadi", count: 0

    get console_loksabhas_path
    assert_select "select[name=state_id] option", text: "Maharashtra"
    assert_select "select[name=district_id] option", text: "Ahmednagar"
    assert_select "input[name=district]", count: 0
  end

  test "creating a district or taluka returns to its show page" do
    assert_difference -> { District.count }, 1 do
      post console_districts_path, params: { record: { name: "Pune", state_id: @state.id, cd: "S1325" } }
    end
    district = District.find_by!(name: "Pune")
    assert_redirected_to console_district_path(district)

    get new_console_taluka_path(district_id: @district.id)
    assert_select "select[name='record[district_id]'] option[selected][value='#{@district.id}']"

    assert_difference -> { Taluka.count }, 1 do
      post console_talukas_path, params: { record: { name: "Karjat", district_id: @district.id } }
    end
    taluka = Taluka.find_by!(name: "Karjat")
    assert_redirected_to console_taluka_path(taluka)

    get edit_console_district_path(@district)
    assert_select "a", text: "Cancel" do |links|
      assert_equal console_district_path(@district), links.first["href"]
    end

    get edit_console_taluka_path(@taluka)
    assert_select "a", text: "Cancel" do |links|
      assert_equal console_taluka_path(@taluka), links.first["href"]
    end
  end
end
