require "test_helper"

# Story 0.3 — the Platform Console requires admin auth and is reached only via the
# admins scope at /console (AC3, AC5).
class ConsoleAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "unauthenticated console access redirects to the admin sign-in" do
    get "/console"
    assert_redirected_to new_admin_session_path
  end

  test "an authenticated admin reaches the console dashboard" do
    admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123", tier: :full)
    sign_in admin
    get "/console"
    assert_response :success
    assert_match "Platform Console", @response.body
  end

  test "the admin sign-in lives under /console" do
    assert_equal "/console/sign_in", new_admin_session_path
  end

  test "a signed-in admin revisiting the console sign-in goes to the console, not the user login" do
    admin = Admin.create!(name: "Dev", email: "dev2@example.com", password: "password123")
    sign_in admin
    get new_admin_session_path
    assert_redirected_to console_root_path
  end

  test "the console renders its operator nav" do
    admin = Admin.create!(name: "Dev", email: "dev3@example.com", password: "password123")
    ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    sign_in admin
    get console_root_path
    assert_response :success
    assert_match "Organizations", @response.body
    assert_match "Platform health", @response.body
    assert_select "aside", true, "console must render a sidebar with nav"
  end
end
