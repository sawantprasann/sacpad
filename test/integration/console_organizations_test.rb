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

  test "an admin can edit the organization and its party history" do
    org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    first = Party.create!(name: "First Party", color: "#112233")
    second = Party.create!(name: "Second Party", color: "#445566")
    org.update!(current_party: first)
    org.party_memberships.create!(party: first, started_at: 1.day.ago)

    sign_in @admin
    patch console_organization_path(org), params: {
      organization: { name: "Org Renamed", current_party_id: second.id }
    }

    assert_redirected_to console_organization_path(org)
    org.reload
    assert_equal "Org Renamed", org.name
    assert_equal second.id, org.current_party_id
    assert org.party_memberships.active.exists?(party_id: second.id)
    assert org.party_memberships.where(party_id: first.id).where.not(ended_at: nil).exists?
  end

  test "the organization page lists every user and can set a new password" do
    org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    role = Role.find_by!(slug: "org_admin")
    root = User.create!(organization: org, role: role, name: "Meera", email: "meera@example.com", password: "password123")
    child = User.create!(organization: org, role: role, name: "Rohan", email: "rohan@example.com", password: "password123", parent: root)

    sign_in @admin
    get console_organization_path(org)
    assert_response :success
    assert_match "meera@example.com", @response.body
    assert_match "rohan@example.com", @response.body
    assert_match "Edit organization", @response.body

    patch reset_password_console_organization_org_user_path(org, child), params: {
      user: { password: "freshpass1", password_confirmation: "freshpass1" }
    }
    assert_redirected_to console_organization_path(org)
    assert child.reload.valid_password?("freshpass1")
    assert_not child.valid_password?("password123")
  end

  test "an admin can email a password reset link" do
    org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    role = Role.find_by!(slug: "org_admin")
    user = User.create!(organization: org, role: role, name: "Meera", email: "meera@example.com", password: "password123")

    sign_in @admin
    assert_emails 1 do
      post send_reset_console_organization_org_user_path(org, user)
    end
    assert_redirected_to console_organization_path(org)
    assert user.reload.reset_password_token.present?
  end

  test "an ops-tier admin cannot edit or reset passwords for an unassigned organization" do
    assigned = ActsAsTenant.without_tenant { Organization.create!(name: "Assigned") }
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Other") }
    role = Role.find_by!(slug: "org_admin")
    outsider = User.create!(organization: other, role: role, name: "Hidden", email: "hidden@example.com", password: "password123")
    ops = Admin.create!(name: "Ops", email: "ops@example.com", password: "password123", tier: :ops)
    ops.organizations << assigned

    sign_in ops
    get edit_console_organization_path(other)
    assert_response :not_found

    sign_in ops
    patch reset_password_console_organization_org_user_path(other, outsider), params: {
      user: { password: "freshpass1", password_confirmation: "freshpass1" }
    }
    assert_response :not_found
    assert outsider.reload.valid_password?("password123")
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
