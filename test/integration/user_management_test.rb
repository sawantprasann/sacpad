require "test_helper"

# Story 0.9 — creating users is gated by can_create_users; each new user is parented to its
# creator; listings are scoped to the viewer's subtree.
class UserManagementTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @org_admin_role = Role.create!(name: "Org Admin", slug: "org_admin", can_create_users: true)
    @plain_role = Role.create!(name: "Karyakarta", slug: "karyakarta", can_create_users: false)
    @admin_user = User.create!(organization: @org, role: @org_admin_role, name: "Meera",
                               email: "meera@example.com", password: "password123")
  end

  test "an org_admin can create a user who becomes their child" do
    sign_in @admin_user
    assert_difference -> { User.count }, 1 do
      post users_path, params: { user: { name: "Rohan", email: "rohan@example.com",
                                         phone: "123", role_id: @plain_role.id } }
    end
    created = User.find_by(email: "rohan@example.com")
    assert_equal @admin_user, created.parent
    assert_equal @org, created.organization
    assert created.pending_invitation?
    assert_not created.active_for_authentication?
  end

  test "a role without can_create_users is denied (404, not 403)" do
    plain = User.create!(organization: @org, role: @plain_role, name: "Rohan",
                         email: "rohan@example.com", password: "password123", parent: @admin_user)
    sign_in plain
    post users_path, params: { user: { name: "X", email: "x@example.com",
                                       role_id: @plain_role.id, password: "password123" } }
    assert_response :not_found
  end

  test "listings are scoped to the viewer's subtree" do
    district = User.create!(organization: @org, role: @plain_role, name: "District",
                            email: "d@example.com", password: "password123", parent: @admin_user)
    peer = User.create!(organization: @org, role: @plain_role, name: "Peer",
                        email: "p@example.com", password: "password123", parent: @admin_user)
    sign_in district
    get users_path
    assert_match "District", @response.body
    assert_no_match(/Peer/, @response.body)
    assert_no_match(/Deactivate/, @response.body)
  end

  test "an org admin can edit, deactivate, and reactivate someone in their team" do
    child = User.create!(organization: @org, role: @plain_role, name: "Rohan",
                         email: "rohan@example.com", password: "password123", parent: @admin_user)
    sign_in @admin_user

    get users_path
    assert_match edit_user_path(child), @response.body
    assert_match deactivate_user_path(child), @response.body
    assert_match send_password_reset_user_path(child), @response.body
    assert_match 'aria-label="Edit"', @response.body
    assert_match 'aria-label="Deactivate"', @response.body
    assert_match 'aria-label="Send password reset"', @response.body
    assert_no_match deactivate_user_path(@admin_user), @response.body

    get edit_user_path(child)
    assert_response :success
    assert_match "Edit user", @response.body

    patch user_path(child), params: { user: { name: "Rohan Patil", email: "rohan.patil@example.com",
                                              phone: "999", role_id: @plain_role.id } }
    assert_redirected_to users_path
    child.reload
    assert_equal "Rohan Patil", child.name
    assert_equal "rohan.patil@example.com", child.email
    assert_equal "999", child.phone

    patch deactivate_user_path(child)
    assert_redirected_to users_path
    assert_not child.reload.active?
    assert_not child.active_for_authentication?

    get users_path
    assert_match reactivate_user_path(child), @response.body

    patch reactivate_user_path(child)
    assert child.reload.active?
    assert child.active_for_authentication?
  end

  test "an org admin can resend an invite, and an email change sends a fresh one" do
    invited = @org.users.new(role: @plain_role, name: "Rohan", email: "rohan@example.com", parent: @admin_user)
    assert invited.deliver_invitation!
    token = invited.invitation_token
    sign_in @admin_user

    get users_path
    assert_match resend_invitation_user_path(invited), @response.body
    assert_match 'aria-label="Resend invite"', @response.body
    assert_no_match send_password_reset_user_path(invited), @response.body

    assert_enqueued_emails 1 do
      post resend_invitation_user_path(invited)
    end
    assert_redirected_to users_path
    assert_not_equal token, invited.reload.invitation_token

    assert_enqueued_emails 1 do
      patch user_path(invited), params: { user: { name: "Rohan", email: "rohan.new@example.com",
                                                   role_id: @plain_role.id } }
    end
    assert_equal "rohan.new@example.com", invited.reload.email
    assert invited.pending_invitation?
  end

  test "an org admin can email a password reset link to someone who already joined" do
    child = User.create!(organization: @org, role: @plain_role, name: "Rohan",
                         email: "rohan@example.com", password: "password123", parent: @admin_user)
    sign_in @admin_user

    I18n.with_locale(:mr) do
      assert_emails 1 do
        post send_password_reset_user_path(child)
      end
    end
    assert_redirected_to users_path
    assert child.reload.reset_password_token.present?

    message = ActionMailer::Base.deliveries.last
    text = message.text_part.body.decoded
    html = message.html_part.body.decoded
    assert_equal "Reset your PolitoMatrix password", message.subject
    assert_match "Hello Rohan,", text
    assert_match "Reset the password for your Org A account on PolitoMatrix.", text
    assert_match "This link expires in 6 hours.", text
    assert_no_match "पासवर्ड", text
    assert_match "#0b1f44", html
    assert_match "#f59e0b", html
    assert_match "Reset password", html

    post resend_invitation_user_path(child)
    assert_response :not_found
  end

  test "an org admin cannot manage their own account or someone outside the team" do
    peer = User.create!(organization: @org, role: @plain_role, name: "Peer",
                        email: "peer@example.com", password: "password123")
    sign_in @admin_user

    patch deactivate_user_path(@admin_user)
    assert_response :not_found
    assert @admin_user.reload.active?

    sign_in @admin_user
    patch user_path(peer), params: { user: { name: "Taken" } }
    assert_response :not_found
    assert_equal "Peer", peer.reload.name

    sign_in @admin_user
    post send_password_reset_user_path(peer)
    assert_response :not_found
    assert_nil peer.reload.reset_password_token
  end

  test "a role without can_create_users cannot edit, deactivate, or reset" do
    plain = User.create!(organization: @org, role: @plain_role, name: "Rohan",
                         email: "rohan@example.com", password: "password123", parent: @admin_user)
    child = User.create!(organization: @org, role: @plain_role, name: "Child",
                         email: "child@example.com", password: "password123", parent: plain)
    sign_in plain

    get edit_user_path(child)
    assert_response :not_found

    sign_in plain
    patch deactivate_user_path(child)
    assert_response :not_found
    assert child.reload.active?

    sign_in plain
    post send_password_reset_user_path(child)
    assert_response :not_found
    assert_nil child.reload.reset_password_token
  end
end
