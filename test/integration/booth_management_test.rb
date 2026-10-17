require "test_helper"

class BoothManagementTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    assembly = State.create!(name: "Maharashtra").loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur")
    @org.update!(constituency: assembly)
    village = assembly.villages.create!(name: "Nimgaon")
    @booth = village.booths.create!(number: "14", name: "School")
    role = Role.create!(name: "Manager", slug: "booth-admin-test")
    role.role_permissions.create!(module_name: "booth_management", access_level: "write")
    role.role_permissions.create!(module_name: "voter_lists", access_level: "read")
    @user = User.create!(organization: @org, role: role, name: "Mina", email: "booths@example.com", password: "password123")
    sign_in @user
  end

  test "a manager can filter and page constituency booths" do
    @booth.update!(address: "School road", station_type: "School")
    21.times { |n| @booth.village.booths.create!(number: (200 + n).to_s, name: "Hall #{n}") }

    get booths_path
    assert_response :success
    assert_match "14", @response.body
    assert_match "School", @response.body
    assert_match "Page 1", @response.body

    get booths_path(number: "14", name: "School", village_id: @booth.village_id, address: "School road", station_type: "School")
    assert_response :success
    assert_match "School", @response.body
    assert_no_match(/Hall 0/, @response.body)

    get booth_path(@booth)
    assert_response :success
    assert_match "School road", @response.body
    assert_no_match(/Checklist/, @response.body)
  end

  test "a booth manager can mark votes and cannot open booth management" do
    sign_out @user
    booth_role = Role.create!(name: "Booth Manager", slug: "only-votes")
    booth_role.role_permissions.create!(module_name: "voter_lists", access_level: "write")
    manager = User.create!(organization: @org, role: booth_role, name: "Agent", email: "agent@example.com", password: "password123")
    sign_in manager

    get root_path
    assert_match "Voter Lists", @response.body
    assert_no_match(/Booth Management/, @response.body)

    get booths_path
    assert_redirected_to root_path
  end
end
