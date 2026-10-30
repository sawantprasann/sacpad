require "test_helper"

class VoterListsTalukasTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    state = State.create!(name: "Maharashtra")
    district = District.create!(name: "Pune", state: state)
    loksabha = state.loksabhas.create!(name: "Baramati", district: district)
    assembly = loksabha.assemblies.create!(name: "Indapur")
    @org.update!(constituency: assembly)
    @taluka = district.talukas.create!(name: "Indapur")
    @other_taluka = district.talukas.create!(name: "Baramati")
    @village = assembly.villages.create!(name: "Nimgaon", taluka: @taluka, police_station: "Indapur PS", pin_code: "413106")
    @other_village = assembly.villages.create!(name: "Kalas", taluka: @taluka, pin_code: "413105")
    @outside_village = assembly.villages.create!(name: "Walchandnagar", taluka: @other_taluka, pin_code: "413114")
    other_assembly = loksabha.assemblies.create!(name: "Purandar")
    @hidden_taluka = district.talukas.create!(name: "Purandar")
    other_assembly.villages.create!(name: "Jejuri", taluka: @hidden_taluka)

    booth_two = @village.booths.create!(number: "2")
    booth_ten = @village.booths.create!(number: "10")
    booth_letter = @village.booths.create!(number: "A")
    @amit = Voter.create!(voter_id: "AMT1111111", first_name: "Amit", last_name: "Kale", sr_no: 8, booth: booth_two, village: @village)
    @zara = Voter.create!(voter_id: "ZRA2222222", first_name: "Zara", last_name: "Pawar", sr_no: 2, booth: booth_two, village: @village)
    @asha = Voter.create!(voter_id: "ASH3333333", first_name: "Asha", last_name: "Patil", sr_no: 1, booth: booth_ten, village: @village)
    @bala = Voter.create!(voter_id: "BAL4444444", first_name: "Bala", last_name: "Shinde", sr_no: 4, booth: booth_letter, village: @village)
    @kalas_voter = Voter.create!(voter_id: "KAL5555555", first_name: "Kiran", last_name: "More", sr_no: 1, village: @other_village)
    ActsAsTenant.with_tenant(@org) do
      VoterSentiment.create!(voter: @amit, sentiment_status: :pleased)
    end

    role = Role.create!(name: "Booth Manager", slug: "voter-lists-taluka")
    role.role_permissions.create!(module_name: "voter_lists", access_level: "write")
    @user = User.create!(organization: @org, role: role, name: "Mina", email: "taluka-voters@example.com", password: "password123")
    sign_in @user
  end

  test "talukas list village counts and open from the row or the show icon" do
    get voter_lists_talukas_path

    assert_response :success
    assert_select "a[href='#{voter_lists_talukas_path}']", text: "Taluka"
    assert_select "a[href='#{voters_path}']", text: "Voter Lists"
    assert_select "tr[data-controller=row-link][data-row-link-url-value='#{voter_lists_taluka_path(@taluka)}']" do
      assert_select "a", text: "Indapur"
      assert_select "td", text: "Pune"
      assert_select "td", text: "2"
      assert_select "a[aria-label=View][href='#{voter_lists_taluka_path(@taluka)}']"
    end
    assert_select "tr[data-row-link-url-value='#{voter_lists_taluka_path(@other_taluka)}']" do
      assert_select "td", text: "1"
    end
    assert_select "a", text: "Purandar", count: 0

    get voter_lists_talukas_path(taluka_id: @other_taluka.id)
    assert_select "a", text: "Baramati"
    assert_select "a[href='#{voter_lists_taluka_path(@taluka)}']", count: 0
  end

  test "a taluka opens its villages the way the console does" do
    get voter_lists_taluka_path(@taluka)

    assert_response :success
    assert_select "dd", text: "2"
    assert_select "tr[data-controller=row-link][data-row-link-url-value='#{voter_lists_taluka_village_path(@taluka, @village)}']" do
      assert_select "a", text: "Nimgaon"
      assert_select "td", text: "Indapur"
      assert_select "td", text: "4"
      assert_select "td", text: "Indapur PS"
      assert_select "td", text: "413106"
      assert_select "a[aria-label=View][href='#{voter_lists_taluka_village_path(@taluka, @village)}']"
    end
    assert_select "a", text: "Walchandnagar", count: 0

    get voter_lists_taluka_path(@taluka, village_id: @other_village.id, pin_code: "413105")
    assert_select "tbody a", text: "Kalas"
    assert_select "tbody a", text: "Nimgaon", count: 0

    get voter_lists_taluka_path(@taluka, police_station: "Indapur")
    assert_select "tbody a", text: "Nimgaon"
    assert_select "tbody a", text: "Kalas", count: 0
  end

  test "a village lists voters by booth number then serial and filters the roll" do
    get voter_lists_taluka_village_path(@taluka, @village)

    assert_response :success
    assert_equal [ "Zara Pawar", "Amit Kale", "Asha Patil", "Bala Shinde" ], voter_names
    assert_match "bg-green-50", response.body
    assert_select "a[href=?]", voter_lists_taluka_village_path(@taluka, @village, format: :xlsx)

    get voter_lists_taluka_village_path(@taluka, @village, voter_id: "AMT1111111", name: "amit", booth: "2", sr_no: 8, sentiment: "pleased")
    assert_equal [ "Amit Kale" ], voter_names

    get voter_lists_taluka_village_path(@taluka, @village, voted: "no")
    assert_includes voter_names, "Zara Pawar"
    assert_not_includes voter_names, "Kiran More"

    patch update_voted_voter_path(@amit), params: {
      voted: "1",
      return_to: voter_lists_taluka_village_path(@taluka, @village, booth: "2")
    }
    assert_redirected_to voter_lists_taluka_village_path(@taluka, @village, booth: "2")

    get voter_lists_taluka_village_path(@taluka, @village, voted: "yes", booth: "2")
    assert_equal [ "Amit Kale" ], voter_names
  end

  test "a village name search matches first and last name without the middle name" do
    Voter.create!(
      voter_id: "TJS0000001", first_name: "Tanaji", middle_name: "Jayvant", last_name: "Savant",
      sr_no: 3, booth: @village.booths.first, village: @village
    )

    get voter_lists_taluka_village_path(@taluka, @village, name: "tanaji savant")
    assert_equal [ "Tanaji Jayvant Savant" ], voter_names
  end

  test "export is limited to the village and keeps booth then serial order" do
    get voter_lists_taluka_village_path(@taluka, @village, format: :xlsx)

    assert_response :success
    assert_match "voters-nimgaon.xlsx", response.headers["Content-Disposition"]
    sheet = workbook.sheet(0)
    assert_equal "Sr no", sheet.cell(1, 1)
    assert_equal [ "Zara Pawar", "Amit Kale", "Asha Patil", "Bala Shinde" ], (2..sheet.last_row).map { |row| sheet.cell(row, 3) }
    assert_equal [ "2", "2", "10", "A" ], (2..sheet.last_row).map { |row| sheet.cell(row, 4).to_s }

    get voter_lists_taluka_village_path(@taluka, @village, format: :xlsx, name: "amit")
    sheet = workbook.sheet(0)
    assert_equal 1, sheet.last_row - 1
    assert_equal "Amit Kale", sheet.cell(2, 3)
  end

  test "a taluka outside the constituency is not reachable" do
    get voter_lists_taluka_path(@hidden_taluka)
    assert_response :not_found
  end

  test "a village opened under the wrong taluka is not reachable" do
    get voter_lists_taluka_village_path(@other_taluka, @village)
    assert_response :not_found
  end

  test "a user without voter list access is turned away" do
    none = Role.create!(name: "No voters", slug: "no-voter-lists")
    outsider = User.create!(organization: @org, role: none, name: "Out", email: "no-taluka-voters@example.com", password: "password123")
    sign_in outsider
    get voter_lists_talukas_path
    assert_redirected_to root_path
  end

  test "a reader can open the roll but cannot mark voted" do
    read = Role.create!(name: "Voter reader", slug: "voter-lists-reader")
    read.role_permissions.create!(module_name: "voter_lists", access_level: "read")
    reader = User.create!(organization: @org, role: read, name: "Nia", email: "reader-taluka@example.com", password: "password123")
    sign_in reader

    get voter_lists_taluka_village_path(@taluka, @village)
    assert_response :success
    assert_select "button", text: "Not voted", count: 0
    assert_match "Not voted", response.body
  end

  private

  def voter_names
    css_select("table tbody tr td:nth-child(3)").map { |cell| cell.text.squish }
  end

  def workbook
    file = Tempfile.new([ "voters", ".xlsx" ])
    file.binmode
    file.write(response.body)
    file.close
    Roo::Spreadsheet.open(file.path, extension: :xlsx)
  end
end
