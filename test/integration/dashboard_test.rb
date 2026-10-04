require "test_helper"

# Story 0.14 — widget-composed dashboard (permission-gated) + per-org party theming.
class DashboardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    org_admin, _dreamline = Role.seed_system_roles!
    @org_admin_role = org_admin

    @limited_role = Role.create!(name: "Ground Coordinator", slug: "ground_coord", can_create_users: false)
    @limited_role.role_permissions.create!(module_name: "ground_reports", access_level: "read")
    @limited_role.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "none")
  end

  def user_with(role, email)
    User.create!(organization: @org, role: role, name: "U", email: email, password: "password123")
  end

  test "an org_admin sees module widgets and org-admin-only widgets" do
    sign_in user_with(@org_admin_role, "admin@example.com")
    get "/"
    assert_match "Open tickets by status", @response.body
    assert_match "Hierarchy &amp; user count", @response.body
  end

  test "a limited role sees only its permitted module widgets and no org-admin widgets" do
    sign_in user_with(@limited_role, "limited@example.com")
    get "/"
    assert_match "Recent ground reports", @response.body
    assert_no_match(/Open tickets by status/, @response.body)
    assert_no_match(/Hierarchy &amp; user count/, @response.body)
  end

  test "the shell carries the org's party accent (AA-safe), defaulting when Independent" do
    sign_in user_with(@org_admin_role, "a@example.com")
    get "/"
    assert_match "--org-party-color:#465FFF", @response.body # Independent -> TailAdmin brand default

    party = Party.create!(name: "Green Party", color: "#10B981")
    @org.update!(current_party: party)
    get "/"
    assert_match "--org-party-color:#10B981", @response.body
  end
end
