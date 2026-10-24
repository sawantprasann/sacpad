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

  test "an org admin or manager can add a booth manager who only sees that booth" do
    booth_role = Role.create!(name: "Booth Manager", slug: "booth_manager")
    booth_role.role_permissions.create!(module_name: "voter_lists", access_level: "write")
    manager_role = Role.create!(name: "Manager", slug: "manager")
    manager_role.role_permissions.create!(module_name: "booth_management", access_level: "write")
    org_admin_role = Role.create!(name: "Org Admin", slug: "org_admin", can_create_users: true)
    org_admin_role.role_permissions.create!(module_name: "booth_management", access_level: "write")

    get booth_path(@booth)
    assert_response :success
    assert_match "No booth manager yet", @response.body
    assert_select "form[action=?]", booth_managers_path(@booth), count: 0

    post booth_managers_path(@booth), params: {
      user: { name: "Blocked", email: "blocked-agent@example.com", password: "password123" }
    }
    assert_redirected_to booth_path(@booth)
    assert_nil User.find_by(email: "blocked-agent@example.com")

    lead = User.create!(organization: @org, role: manager_role, name: "Lead", email: "lead@example.com", password: "password123")
    sign_in lead
    get booth_path(@booth)
    assert_select "form[action=?]", booth_managers_path(@booth)
    assert_select "input[name=?]", "user[name]"

    assert_no_difference -> { User.count } do
      post booth_managers_path(@booth), params: {
        user: { name: "Agent", email: "agent-booth@example.com", password: "short" }
      }
    end
    assert_redirected_to booth_path(@booth)

    assert_difference -> { User.count }, 1 do
      post booth_managers_path(@booth), params: {
        user: { name: "Agent", email: "agent-booth@example.com", phone: "9990001111", password: "password123" }
      }
    end
    agent = User.find_by!(email: "agent-booth@example.com")
    assert_equal booth_role, agent.role
    assert_equal @booth, agent.booth
    assert_equal lead, agent.parent
    follow_redirect!
    assert_match "Agent", @response.body
    assert_match "9990001111", @response.body

    admin = User.create!(organization: @org, role: org_admin_role, name: "Meera", email: "meera-booth@example.com", password: "password123")
    sign_in admin
    post booth_managers_path(@booth), params: {
      user: { name: "Second", email: "second-agent@example.com", password: "password123" }
    }
    assert_equal @booth, User.find_by!(email: "second-agent@example.com").booth

    other = @booth.village.booths.create!(number: "2", name: "Hall")
    own = Voter.create!(voter_id: "OWN1111111", first_name: "Asha", last_name: "Patil", booth: @booth, village: @booth.village, sr_no: 1)
    foreign = Voter.create!(voter_id: "OUT2222222", first_name: "Ravi", last_name: "Kale", booth: other, village: @booth.village, sr_no: 2)
    sign_in agent
    get voters_path
    assert_response :success
    assert_match own.voter_id, @response.body
    assert_no_match(/OUT2222222/, @response.body)
    get voter_path(foreign)
    assert_response :not_found
    get booths_path
    assert_redirected_to root_path
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
