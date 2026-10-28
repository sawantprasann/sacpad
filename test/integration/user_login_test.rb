require "test_helper"

# Story 0.7 — org users log in at the clean root path; login tracking increments (NFR26).
class UserLoginTest < ActionDispatch::IntegrationTest
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @role = Role.create!(name: "Org Admin", slug: "org_admin")
    @user = User.create!(organization: @org, role: @role, name: "Rohan",
                         email: "rohan@example.com", password: "password123")
  end

  test "the user sign-in lives at the clean root path" do
    assert_equal "/sign_in", new_user_session_path
  end

  test "signing in records the timestamp and increments the login counter" do
    post user_session_path, params: { user: { email: "rohan@example.com", password: "password123" } }
    assert_response :redirect
    @user.reload
    assert_equal 1, @user.sign_in_count
    assert_not_nil @user.current_sign_in_at
  end

  test "the top bar shows the signed-in user and a way to change the password" do
    post user_session_path, params: { user: { email: "rohan@example.com", password: "password123" } }
    follow_redirect!
    assert_match "Rohan", @response.body
    assert_match "Sign-ins", @response.body
    assert_select "a[href='#{edit_account_password_path}']", text: "Change password"
  end

  test "a signed-in user can replace their password" do
    post user_session_path, params: { user: { email: "rohan@example.com", password: "password123" } }

    patch account_password_path, params: {
      user: { current_password: "wrong", password: "newpassword", password_confirmation: "newpassword" }
    }
    assert_response :unprocessable_entity
    assert @user.reload.valid_password?("password123")

    patch account_password_path, params: {
      user: { current_password: "password123", password: "newpassword", password_confirmation: "newpassword" }
    }
    assert_redirected_to root_path
    assert @user.reload.valid_password?("newpassword")
    follow_redirect!
    assert_match "Password updated.", response.body
  end
end
