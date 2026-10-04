require "test_helper"

# Story 0.11 — viewing an org's data is logged + banner-flagged; the audit log is queryable
# and ops-scoped.
class ConsoleAuditTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123", tier: :full)
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Candidate A") }
  end

  test "viewing an org logs the access and shows the persistent banner" do
    sign_in @admin
    assert_difference -> { ActivityLog.where(action: "organization.viewed").count }, 1 do
      get console_organization_path(@org)
    end
    assert_response :success
    assert_match "This access is logged", @response.body
    log = ActivityLog.where(action: "organization.viewed").last
    assert_equal @admin, log.actor
    assert_equal @org.id, log.organization_id
  end

  test "the audit log lists entries" do
    ActivityLog.record!(actor: @admin, action: "organization.viewed", organization: @org)
    sign_in @admin
    get console_audit_logs_path
    assert_response :success
    assert_match "organization.viewed", @response.body
  end

  test "an ops admin only sees audit entries for assigned orgs" do
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Other") }
    ActivityLog.record!(actor: @admin, action: "organization.viewed", organization: @org)
    ActivityLog.record!(actor: @admin, action: "organization.viewed", organization: other)

    ops = Admin.create!(name: "Ops", email: "ops@example.com", password: "password123", tier: :ops)
    ops.organizations << @org
    sign_in ops
    get console_audit_logs_path
    assert_select "tbody tr", 1
  end
end
