require "test_helper"

class InvitationsTest < ActionDispatch::IntegrationTest
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @role = Role.create!(name: "Org Admin", slug: "org_admin")
    @user = @org.users.new(role: @role, name: "Meera", email: "meera@example.com")
    assert @user.deliver_invitation!
    @token = enqueued_jobs.last[:args].dig(3, "args", 1)
    perform_enqueued_jobs
    assert_match @token, ActionMailer::Base.deliveries.last.body.encoded
  end

  test "an invited user cannot sign in until the invite is accepted" do
    @user.update!(password: "password123", password_confirmation: "password123")

    post user_session_path, params: { user: { email: "meera@example.com", password: "password123" } }
    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match I18n.t("devise.failure.pending_invitation"), response.body
    assert_equal 0, @user.reload.sign_in_count
  end

  test "accepting the invite sets the password and signs the user in" do
    get edit_invitation_path(@token)
    assert_response :success
    assert_match "Accept your invite", response.body

    patch invitation_path(@token), params: {
      user: { password: "newpassword", password_confirmation: "newpassword" }
    }
    assert_redirected_to root_path
    follow_redirect!
    assert_match "Meera", response.body

    @user.reload
    assert_not @user.pending_invitation?
    assert @user.valid_password?("newpassword")
  end

  test "invite email stays in English when the organization language is Marathi" do
    state = State.create!(name: "Invite State #{SecureRandom.hex(2)}")
    loksabha = Loksabha.create!(name: "Invite Seat", state: state, native_locale: "mr")
    org = ActsAsTenant.without_tenant { Organization.create!(name: "मराठी संघटना", constituency: loksabha) }
    user = org.users.new(role: @role, name: "Meera", email: "marathi-invite@example.com")

    assert_equal "mr", org.native_locale
    assert user.deliver_invitation!
    perform_enqueued_jobs

    message = ActionMailer::Base.deliveries.last
    text = message.text_part.body.decoded
    html = message.html_part.body.decoded
    assert_equal "मराठी संघटना invited you to PolitoMatrix", message.subject
    assert_match "Hello Meera,", text
    assert_match "मराठी संघटना has invited you to PolitoMatrix.", text
    assert_match "Choose a password to sign in.", text
    assert_no_match "निमंत्रण", text
    assert_match "#0b1f44", html
    assert_match "#f59e0b", html
    assert_match "Accept invite", html
  end

  test "a used invite link cannot be opened again" do
    patch invitation_path(@token), params: {
      user: { password: "newpassword", password_confirmation: "newpassword" }
    }

    get edit_invitation_path(@token)
    assert_redirected_to new_user_session_path
  end
end
