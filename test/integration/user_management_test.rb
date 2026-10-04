require "test_helper"

# Story 0.9 — creating users is gated by can_create_users; each new user is parented to its
# creator; listings are scoped to the viewer's subtree.
class UserManagementTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @org_admin_role = Role.create!(name: "Org Admin", slug: "org_admin", can_create_users: true)
    @plain_role = Role.create!(name: "Karyakarta", slug: "karyakarta", can_create_users: false)
    @admin_user = User.create!(organization: @org, role: @org_admin_role, name: "Meera",
                               email: "meera@example.com", password: "password123")
  end

  test "an org_admin can create a user who becomes their child" do
    sign_in @admin_user
    assert_difference -> { User.count }, 1 do
      post users_path, params: { user: { name: "Rohan", email: "rohan@example.com",
                                         phone: "123", role_id: @plain_role.id, password: "password123" } }
    end
    created = User.find_by(email: "rohan@example.com")
    assert_equal @admin_user, created.parent
    assert_equal @org, created.organization
  end

  test "a role without can_create_users is denied (404, not 403)" do
    plain = User.create!(organization: @org, role: @plain_role, name: "Rohan",
                         email: "rohan@example.com", password: "password123", parent: @admin_user)
    sign_in plain
    post users_path, params: { user: { name: "X", email: "x@example.com",
                                       role_id: @plain_role.id, password: "password123" } }
    assert_response :not_found
  end

  test "listings are scoped to the viewer's subtree" do
    district = User.create!(organization: @org, role: @plain_role, name: "District",
                            email: "d@example.com", password: "password123", parent: @admin_user)
    peer = User.create!(organization: @org, role: @plain_role, name: "Peer",
                        email: "p@example.com", password: "password123", parent: @admin_user)
    sign_in district
    get users_path
    assert_match "District", @response.body
    assert_no_match(/Peer/, @response.body)
  end
end
