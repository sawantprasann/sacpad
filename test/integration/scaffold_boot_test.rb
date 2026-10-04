require "test_helper"

# Story 0.1 — proves the scaffold boots and renders the shared shell (AC3, AC5).
class ScaffoldBootTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "root renders inside the shared shell for a signed-in user" do
    org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    role = Role.create!(name: "Org Admin", slug: "org_admin")
    user = User.create!(organization: org, role: role, name: "Meera",
                        email: "meera@example.com", password: "password123")
    sign_in user
    get root_path
    assert_response :success
    assert_select "aside", true, "shared sidebar region should render"
    assert_select "header", true, "shared top-bar region should render"
    assert_select "main", true, "content region should render"
    assert_match "SAC-PAD", @response.body
  end

  test "an unauthenticated visitor is sent to the shell-less sign-in page" do
    get root_path
    assert_redirected_to new_user_session_path
  end

  test "health check boots with no exceptions" do
    get rails_health_check_path
    assert_response :success
  end
end
