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

  test "a Lok Sabha opens onto its assemblies" do
    sign_in @admin
    get console_loksabhas_path

    assert_response :success
    assert_select "a", text: "View"
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

  test "editing an assembly stays on that assembly" do
    sign_in @admin
    patch console_loksabha_assembly_path(@loksabha, @assembly), params: { record: { name: "Paranda Updated", constituency_no: "244" } }

    assert_redirected_to console_loksabha_assembly_path(@loksabha, @assembly)
    assert_equal "Paranda Updated", @assembly.reload.name
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
    assert_select "a[href='#{console_loksabha_path(@other)}']", text: "View"
    assert_select "a[href='#{console_loksabha_path(@loksabha)}']", count: 0

    get console_loksabha_path(@loksabha, name: "Ashti")
    assert_select "a[href='#{console_loksabha_assembly_path(@loksabha, ashti)}']", text: "Ashti"
    assert_select "a[href='#{console_loksabha_assembly_path(@loksabha, @assembly)}']", count: 0

    get console_loksabha_assembly_path(@loksabha, @assembly, taluka: "Paranda", pin_code: "413502")
    assert_match "Nagathali", response.body
    assert_no_match "Shindewadi", response.body

    get console_loksabha_assembly_village_path(@loksabha, @assembly, @village, name: "Asha", gender: "Female")
    assert_match "Asha", response.body
    assert_no_match "Ravi", response.body
  end
end
