require "test_helper"

# Story 0.1a (fix) — Devise pages use a standalone centered auth layout: NO app shell/sidebar
# on the login page, and the TailAdmin sign-in markup renders.
class AuthLayoutTest < ActionDispatch::IntegrationTest
  test "the user sign-in page has no app sidebar (standalone auth layout)" do
    get new_user_session_path
    assert_response :success
    assert_select "aside", false, "login page must NOT render the app sidebar"
    assert_select "nav.sidebar", false
    assert_match "Sign In", @response.body
    assert_match "PolitoMatrix", @response.body
    assert_match "Changed Policies with Changing Politics", @response.body
    assert_no_match(/Campaign desk/, @response.body)
    assert_match "© #{Date.current.year} PolitoMatrix", @response.body
  end

  test "the admin console sign-in also uses the auth layout (no steel shell)" do
    get new_admin_session_path
    assert_response :success
    assert_select "aside", false
    assert_match "Sign In", @response.body
  end

  test "the forgot-password page is themed and shell-less" do
    get new_user_password_path
    assert_response :success
    assert_select "aside", false
    assert_match "Forgot your password?", @response.body
    assert_match "campaign-btn", @response.body
    assert_match "focus:border-orange-400", @response.body
    assert_no_match(/bg-brand-950/, @response.body)
  end
end
