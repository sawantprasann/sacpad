require "test_helper"

# Stories 0.5/0.6 — onboarding wizard, health list, ops-tier scoping, deactivation cascade.
class ConsoleOrganizationsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Role.seed_system_roles!
    @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123", tier: :full)
  end

  test "onboarding creates the org and its first Org Admin" do
    sign_in @admin
    assert_difference [ -> { Organization.count }, -> { User.count } ], 1 do
      post console_organizations_path, params: {
        organization: { name: "Candidate A", constituency_type: "Assembly", constituency_id: 1 },
        org_admin: { name: "Meera", email: "meera@example.com", password: "password123" }
      }
    end
    org = Organization.find_by(name: "Candidate A")
    assert_equal "Assembly", org.constituency_type
    assert_equal "org_admin", org.users.first.role.slug
  end

  test "onboarding without an initial Org Admin is rejected" do
    sign_in @admin
    assert_no_difference -> { Organization.count } do
      post console_organizations_path, params: {
        organization: { name: "No Admin Org", constituency_type: "Assembly", constituency_id: 1 },
        org_admin: { name: "", email: "", password: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "deactivating an org cascades to block every user under it" do
    org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    role = Role.find_by(slug: "org_admin")
    user = User.create!(organization: org, role: role, name: "Meera",
                        email: "meera@example.com", password: "password123")
    assert user.active_for_authentication?

    org.deactivate!
    assert_not user.reload.active_for_authentication?
    org.reactivate!
    assert user.reload.active_for_authentication?
  end

  test "an ops-tier admin only sees assigned organizations" do
    assigned = ActsAsTenant.without_tenant { Organization.create!(name: "Assigned") }
    _other   = ActsAsTenant.without_tenant { Organization.create!(name: "Other") }
    ops = Admin.create!(name: "Ops", email: "ops@example.com", password: "password123", tier: :ops)
    ops.organizations << assigned

    sign_in ops
    get console_organizations_path
    assert_match "Assigned", @response.body
    assert_no_match(/Other/, @response.body)
  end
end
