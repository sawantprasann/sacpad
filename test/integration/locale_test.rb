require "test_helper"

class LocaleTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Locale Org #{SecureRandom.hex(4)}") }
    state = State.create!(name: "Locale State #{SecureRandom.hex(2)}")
    loksabha = Loksabha.create!(name: "Locale Seat", state: state, native_locale: "mr")
    @org.update!(constituency: loksabha)
    role = Role.create!(name: "Locale Role", slug: "locale-role-#{SecureRandom.hex(4)}")
    @user = User.create!(
      organization: @org,
      role: role,
      name: "Meera",
      email: "locale-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
  end

  test "english is the default and marathi switches the shell" do
    sign_in @user

    get root_path
    assert_response :success
    assert_select "html[lang=en]"
    assert_select "span.menu-item-text", text: "Dashboard"
    assert_equal "en", @user.preferred_locale

    patch locale_path, params: { locale: "mr" }, headers: { "Referer" => root_url }
    assert_redirected_to root_url
    assert_equal "mr", @user.reload.preferred_locale

    follow_redirect!
    assert_response :success
    assert_select "html[lang=mr]"
    assert_select "span.menu-item-text", text: "डॅशबोर्ड"
    assert_match "भाषा बदलली.", response.body
  end

  test "a signed-in user only gets English and the Lok Sabha language" do
    sign_in @user

    patch locale_path, params: { locale: "ta" }, headers: { "Referer" => root_url }
    assert_redirected_to root_url
    assert_equal "en", @user.reload.preferred_locale
  end

  test "an unknown locale is rejected" do
    sign_in @user

    patch locale_path, params: { locale: "hi" }, headers: { "Referer" => root_url }
    assert_redirected_to root_url
    assert_equal "en", @user.reload.preferred_locale

    follow_redirect!
    assert_match "That language is not available.", response.body
    assert_select "html[lang=en]"
  end

  test "the sign-in page keeps the chosen language" do
    patch locale_path, params: { locale: "mr" }, headers: { "Referer" => new_user_session_url }
    assert_redirected_to new_user_session_url

    follow_redirect!
    assert_response :success
    assert_select "html[lang=mr]"
    assert_select "h1", text: "साइन इन"
    assert_select "input[type=submit][value=?]", "साइन इन"
  end

  test "the platform console stays in english" do
    patch locale_path, params: { locale: "mr" }

    get new_admin_session_path
    assert_response :success
    assert_select "html[lang=en]"
    assert_select "h1", text: "Sign In"
  end
end
