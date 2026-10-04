require "test_helper"

# Story 0.1 — proves the scaffold boots and renders the shared shell (AC3, AC5).
class ScaffoldBootTest < ActionDispatch::IntegrationTest
  test "root renders inside the shared shell" do
    get root_path
    assert_response :success
    assert_select "aside", true, "shared sidebar region should render"
    assert_select "header", true, "shared top-bar region should render"
    assert_select "main", true, "content region should render"
    assert_match "SAC-PAD", @response.body
  end

  test "health check boots with no exceptions" do
    get rails_health_check_path
    assert_response :success
  end
end
