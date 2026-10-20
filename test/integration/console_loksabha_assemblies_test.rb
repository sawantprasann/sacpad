require "test_helper"

class ConsoleLoksabhaAssembliesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123", tier: :full)
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: state, cd: "S1326")
    @loksabha = Loksabha.create!(name: "Ahmednagar", state: state, district: district, constituency_no: "37")
    @other = Loksabha.create!(name: "Beed", state: state, district: district, constituency_no: "38")
    @assembly = @loksabha.assemblies.create!(name: "Paranda", constituency_no: "244")
    @other.assemblies.create!(name: "Elsewhere", constituency_no: "230")
    @village = @assembly.villages.create!(name: "Nagathali", police_station: "Paranda PS", pin_code: "413502")
    booth = @village.booths.create!(number: "2")
    Voter.create!(
      voter_id: "BBB2222222", first_name: "Ravi", last_name: "Kale",
      age: 34, gender: "Male", house_no: "12", booth: booth, village: @village
    )
  end

  test "deleting a loksabha that still has assemblies is blocked and shows why" do
    sign_in @admin

    assert_no_difference -> { Loksabha.count } do
      delete console_loksabha_path(@loksabha)
    end

    assert_redirected_to console_loksabhas_path
    follow_redirect!
    assert_select "[role=alertdialog] p", text: /Ahmednagar can't be deleted while it still has assemblies\. Remove them first, then try again\./
    assert_no_match "Loksabha deleted", response.body
  end

  test "an admin can delete a loksabha that has no assemblies" do
    sign_in @admin
    empty = Loksabha.create!(name: "Empty", state: @loksabha.state, district: @loksabha.district, constituency_no: "99")

    assert_difference -> { Loksabha.count }, -1 do
      delete console_loksabha_path(empty)
    end

    assert_redirected_to console_loksabhas_path
    follow_redirect!
    assert_select "[role=dialog] p", text: "Loksabha deleted."
  end

  test "a Lok Sabha opens onto its assemblies" do
    sign_in @admin
    get console_loksabhas_path

    assert_response :success
    assert_select "a[aria-label=View]"
    assert_select "a", text: "Assemblies", count: 0

    get console_loksabha_path(@loksabha)
    assert_response :success
    assert_select "a[href='#{console_loksabha_assembly_path(@loksabha, @assembly)}']", text: "Paranda"
    assert_no_match "Elsewhere", response.body
  end

  test "creating an assembly returns to that assembly" do
    sign_in @admin

    assert_difference -> { @loksabha.assemblies.count }, 1 do
      post console_loksabha_assemblies_path(@loksabha), params: { record: { name: "Ashti", constituency_no: "226" } }
    end
    assembly = @loksabha.assemblies.find_by!(name: "Ashti")
    assert_redirected_to console_loksabha_assembly_path(@loksabha, assembly)
  end

  test "edit forms link Cancel back to the record or its parent list" do
    sign_in @admin

    get edit_console_loksabha_path(@loksabha)
    assert_response :success
    assert_select "a", text: "Cancel" do |links|
      assert_equal console_loksabha_path(@loksabha), links.first["href"]
    end

    get new_console_loksabha_path
    assert_response :success
    assert_select "a", text: "Cancel" do |links|
      assert_equal console_loksabhas_path, links.first["href"]
    end

    get edit_console_loksabha_assembly_path(@loksabha, @assembly)
    assert_response :success
    assert_select "a", text: "Cancel" do |links|
      assert_equal console_loksabha_assembly_path(@loksabha, @assembly), links.first["href"]
    end

    get new_console_loksabha_assembly_path(@loksabha)
    assert_response :success
    assert_select "a", text: "Cancel" do |links|
      assert_equal console_loksabha_path(@loksabha), links.first["href"]
    end

    get edit_console_loksabha_assembly_village_path(@loksabha, @assembly, @village)
    assert_response :success
    assert_select "a", text: "Cancel" do |links|
      assert_equal console_loksabha_assembly_village_path(@loksabha, @assembly, @village), links.first["href"]
    end

    get new_console_loksabha_assembly_village_path(@loksabha, @assembly)
    assert_response :success
    assert_select "a", text: "Cancel" do |links|
      assert_equal console_loksabha_assembly_path(@loksabha, @assembly), links.first["href"]
    end
  end

  test "editing an assembly stays on that assembly" do
    sign_in @admin
    patch console_loksabha_assembly_path(@loksabha, @assembly), params: {
      record: { name: "Paranda Updated", constituency_no: "244", first_part: "1", last_part: "355" }
    }

    assert_redirected_to console_loksabha_assembly_path(@loksabha, @assembly)
    @assembly.reload
    assert_equal "Paranda Updated", @assembly.name
    assert_equal 1, @assembly.first_part
    assert_equal 355, @assembly.last_part
  end

  test "an assembly opens onto its villages and a village lists its voters" do
    sign_in @admin
    get console_loksabha_assembly_path(@loksabha, @assembly)

    assert_response :success
    assert_match "Nagathali", response.body
    assert_match "Paranda PS", response.body

    get console_loksabha_assembly_village_path(@loksabha, @assembly, @village)
    assert_response :success
    assert_match "Ravi", response.body
    assert_match "BBB2222222", response.body
    assert_match "12", response.body
  end

  test "filters keep only the matching rows" do
    sign_in @admin
    ashti = @loksabha.assemblies.create!(name: "Ashti", constituency_no: "226")
    taluka = Taluka.create!(name: "Paranda", district: @loksabha.district)
    @village.update!(taluka: taluka)
    @assembly.villages.create!(name: "Shindewadi", pin_code: "413501")
    booth = @village.booths.create!(number: "3")
    Voter.create!(
      voter_id: "AAA1111111", first_name: "Asha", last_name: "Patil",
      age: 40, gender: "Female", house_no: "4", booth: booth, village: @village
    )

    get console_loksabhas_path(name: "Beed")
    assert_select "a[href='#{console_loksabha_path(@other)}'][aria-label=View]"
    assert_select "a[href='#{console_loksabha_path(@loksabha)}']", count: 0

    get console_loksabha_path(@loksabha, name: "Ashti")
    assert_select "a[href='#{console_loksabha_assembly_path(@loksabha, ashti)}']", text: "Ashti"
    assert_select "a[href='#{console_loksabha_assembly_path(@loksabha, @assembly)}']", count: 0

    get console_loksabha_assembly_path(@loksabha, @assembly)
    assert_select "select[name=taluka_id] option", text: "Paranda"
    assert_select "input[name=taluka]", count: 0

    get console_loksabha_assembly_path(@loksabha, @assembly, taluka_id: taluka.id, pin_code: "413502")
    assert_match "Nagathali", response.body
    assert_no_match "Shindewadi", response.body

    get console_loksabha_assembly_village_path(@loksabha, @assembly, @village, name: "Asha", gender: "Female")
    assert_match "Asha", response.body
    assert_no_match "Ravi", response.body
  end
end
