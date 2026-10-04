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
end
