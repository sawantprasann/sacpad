require "test_helper"

class ConsoleVotersListTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123", tier: :full)
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: state, cd: "S1326")
    loksabha = Loksabha.create!(name: "Ahmednagar", state: state, district: district, constituency_no: "37")
    assembly = loksabha.assemblies.create!(name: "Ahmednagar City", constituency_no: "255")
    @village = assembly.villages.create!(name: "Shindewadi")
    @other = assembly.villages.create!(name: "Nagathali")
    first = @village.booths.create!(number: "1")
    second = @other.booths.create!(number: "2")
    Voter.create!(voter_id: "AAA1111111", first_name: "Asha", last_name: "Patil", booth: first, village: @village)
    Voter.create!(voter_id: "BBB2222222", first_name: "Ravi", last_name: "Kale", booth: second, village: @other)
  end

  test "the voter list loads every booth in one query" do
    sign_in @admin
    queries = []
    callback = lambda { |*, payload|
      sql = payload[:sql].to_s
      queries << sql if payload[:name] != "SCHEMA" && sql.match?(/\ASELECT/i)
    }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get console_voters_path
    end

    assert_response :success
    # One preload for the table rows, plus the coverage total across booths.
    assert_operator queries.count { |sql| sql.include?('"booths"') }, :<=, 2
  end

  test "the list shows serial numbers and filters by them" do
    Voter.find_by!(voter_id: "AAA1111111").update!(sr_no: 12)
    Voter.find_by!(voter_id: "BBB2222222").update!(sr_no: 4)
    sign_in @admin

    get console_voters_path
    assert_response :success
    assert_select "th", text: "Sr no"
    assert_select "input[name=sr_no]"

    get console_voters_path(sr_no: 12)
    assert_response :success
    assert_match "Asha", response.body
    assert_no_match "Ravi", response.body

    get console_voter_path(Voter.find_by!(voter_id: "AAA1111111"))
    assert_response :success
    assert_match "Sr no", response.body
    assert_match "12", response.body
  end

  test "filters by voter id, village, booth, and name together" do
    sign_in @admin

    get console_voters_path(voter_id: "AAA1111111")
    assert_response :success
    assert_match "Asha", response.body
    assert_no_match "Ravi", response.body

    get console_voters_path
    assert_response :success
    assert_select "select[name=village_id] option", text: "Nagathali"
    assert_select "input[name=village]", count: 0

    get console_voters_path(village_id: @other.id, booth: "2", name: "kale")
    assert_response :success
    assert_match "Ravi", response.body
    assert_no_match "Asha", response.body
  end

  test "the list offers edit and an admin can correct the voter" do
    voter = Voter.find_by!(voter_id: "AAA1111111")
    sign_in @admin
    I18n.locale = :mr

    get console_voters_path
    assert_response :success
    assert_select "a[href=?][aria-label=Edit]", edit_console_voter_path(voter)

    get edit_console_voter_path(voter)
    assert_response :success
    assert_select "input[name=?][value=?]", "voter[first_name]", "Asha"

    patch console_voter_path(voter), params: { voter: { first_name: "Asha", last_name: "More", mobile: "9999999999" } }
    assert_redirected_to console_voter_path(voter)
    voter.reload
    assert_equal "More", voter.last_name
    assert_equal "9999999999", voter.mobile
  ensure
    I18n.locale = I18n.default_locale
  end

  test "the index compares fetched voters with the counts stored from booth PDFs" do
    Booth.find_by!(number: "1").update!(male_electors: 3, female_electors: 2, other_electors: 1)
    Voter.find_by!(voter_id: "AAA1111111").update!(gender: "Male")
    Voter.find_by!(voter_id: "BBB2222222").update!(gender: "Female")
    Voter.create!(
      voter_id: "CCC3333333", first_name: "Neel", last_name: "Shah",
      gender: "Third Gender", booth: @village.booths.find_by!(number: "1"), village: @village
    )
    sign_in @admin

    get console_voters_path

    assert_response :success
    assert_select "h2", text: "Voter coverage"
    assert_select "[data-coverage=fetched-total]", text: "3"
    assert_select "[data-coverage=pdf-total]", text: "6"
    assert_select "[data-coverage=missing-total]", text: "3"
    assert_select "[data-coverage=fetched-male]", text: "1"
    assert_select "[data-coverage=pdf-male]", text: "3"
    assert_select "[data-coverage=missing-male]", text: "2"
    assert_select "[data-coverage=fetched-female]", text: "1"
    assert_select "[data-coverage=pdf-female]", text: "2"
    assert_select "[data-coverage=missing-female]", text: "1"
    assert_select "[data-coverage=fetched-others]", text: "1"
    assert_select "[data-coverage=pdf-others]", text: "1"
    assert_select "[data-coverage=missing-others]", text: "0"
  end

  test "coverage leaves the PDF columns blank when no booth has stored counts" do
    sign_in @admin

    get console_voters_path

    assert_response :success
    assert_select "[data-coverage=fetched-total]", text: "2"
    assert_select "[data-coverage=pdf-total]", text: "—"
    assert_select "[data-coverage=missing-total]", text: "—"
  end

  test "a name search alone asks for another filter" do
    sign_in @admin

    get console_voters_path(name: "Asha")

    assert_response :success
    assert_match "Add a village, booth, voter ID, or Sr no to search by name.", response.body
    assert_match "Ravi", response.body
  end
end
