require "test_helper"

class ConsoleVotersListTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123", tier: :full)
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: state, cd: "S1326")
    loksabha = Loksabha.create!(name: "Ahmednagar", state: state, district: district, constituency_no: "37")
    assembly = loksabha.assemblies.create!(name: "Ahmednagar City", constituency_no: "255")
    village = assembly.villages.create!(name: "Shindewadi")
    other = assembly.villages.create!(name: "Nagathali")
    first = village.booths.create!(number: "1")
    second = other.booths.create!(number: "2")
    Voter.create!(voter_id: "AAA1111111", first_name: "Asha", last_name: "Patil", booth: first, village: village)
    Voter.create!(voter_id: "BBB2222222", first_name: "Ravi", last_name: "Kale", booth: second, village: other)
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
    assert_operator queries.count { |sql| sql.include?('"booths"') }, :<=, 1
  end

  test "filters by voter id, village, booth, and name together" do
    sign_in @admin

    get console_voters_path(voter_id: "AAA1111111")
    assert_response :success
    assert_match "Asha", response.body
    assert_no_match "Ravi", response.body

    get console_voters_path(village: "Nagathali", booth: "2", name: "kale")
    assert_response :success
    assert_match "Ravi", response.body
    assert_no_match "Asha", response.body
  end

  test "a name search alone asks for another filter" do
    sign_in @admin

    get console_voters_path(name: "Asha")

    assert_response :success
    assert_match "Add a village, booth, or voter ID to search by name.", response.body
    assert_match "Ravi", response.body
  end
end
