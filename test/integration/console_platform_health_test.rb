require "test_helper"

# Story 0.13 — the platform health view is Admin-only and renders available metrics.
class ConsolePlatformHealthTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "requires admin auth" do
    get console_platform_health_path
    assert_redirected_to new_admin_session_path
  end

  test "renders health metrics for an admin" do
    admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123")
    ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    sign_in admin
    get console_platform_health_path
    assert_response :success
    assert_match "Platform health", @response.body
    assert_match "Organizations", @response.body
  end
end
