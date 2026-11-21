require "test_helper"

class AccountSettingsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Settings Org") }
    @role = Role.create!(name: "Org Admin", slug: "org_admin-#{SecureRandom.hex(4)}")
    @user = User.create!(organization: @org, role: @role, name: "Rohan", phone: "9000000000",
                         email: "rohan-settings@example.com", password: "password123")
  end

  test "a guest is sent to sign in" do
    get account_settings_path
    assert_redirected_to new_user_session_path
  end

  test "the menu and sidebar open account settings" do
    sign_in @user
    get account_settings_path
    assert_response :success
    assert_select "h1", text: I18n.t("settings.title")
    assert_select "input[name=?][value=?]", "user[name]", "Rohan"
    assert_select "input[name=?][value=?]", "user[email]", "rohan-settings@example.com"
    assert_select "input[name=?][value=?]", "user[phone]", "9000000000"
    assert_select "input[id=workspace_name][disabled][value=?]", "Settings Org"
    assert_select "form#account_password input[name=?]", "user[current_password]"
    assert_select "form#account_password input[name=?]", "user[password]"
    assert_select "form#account_password input[name=?]", "user[password_confirmation]"
    assert_select "a[href=?]", edit_account_password_path, count: 0
    assert_select "a[href=?]", account_settings_path
    assert_no_match I18n.t("settings.social_title"), response.body
  end

  test "a signed-in user updates their name, email, phone, and photo" do
    sign_in @user
    photo = fixture_file_upload("photo.png", "image/png")

    patch account_settings_path, params: {
      user: { name: "Rohan Sawant", email: "rohan.sawant@example.com", phone: "9876543210", photo: photo }
    }

    assert_redirected_to account_settings_path
    @user.reload
    assert_equal "Rohan Sawant", @user.name
    assert_equal "rohan.sawant@example.com", @user.email
    assert_equal "9876543210", @user.phone
    assert @user.photo.attached?
    assert_equal "image/png", @user.photo.content_type
    follow_redirect!
    assert_match I18n.t("settings.saved"), response.body
  end

  test "a blank name and a non-image file are rejected" do
    sign_in @user

    patch account_settings_path, params: { user: { name: "", email: @user.email } }
    assert_response :unprocessable_entity
    assert_equal "Rohan", @user.reload.name

    patch account_settings_path, params: {
      user: { name: "Rohan", email: @user.email, photo: fixture_file_upload("photo.png", "image/gif") }
    }
    assert_response :unprocessable_entity
    assert_match I18n.t("settings.photo_invalid"), response.body
    assert_not @user.reload.photo.attached?
  end

  test "an organization admin connects and disconnects social accounts from settings" do
    grant_social_admin!
    page = nil
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.create!(
        owner: @user, provider: :facebook, external_id: "111", name: "Youth Page",
        access_token: "page-secret-token", status: :active
      )
    end

    sign_in @user
    api = MetaApi.singleton_class
    api.alias_method(:__orig_configured?, :configured?)
    MetaApi.define_singleton_method(:configured?) { false }
    get account_settings_path
    assert_response :success
    assert_match "Youth Page", response.body
    assert_no_match "page-secret-token", response.body
    assert_select "button[data-network=facebook][disabled]"
    assert_select "button[data-network=youtube][disabled]", text: I18n.t("social.coming_next")
    assert_select "form[action=?]", social_connection_path(page)

    MetaApi.define_singleton_method(:configured?) { true }
    get account_settings_path
    assert_select "form[action='/auth/facebook'] button[data-network=facebook]", text: I18n.t("social.connect")
    assert_select "form[action='/auth/facebook'] button[data-network=instagram]", text: I18n.t("social.connect")
  ensure
    api&.alias_method(:configured?, :__orig_configured?) if api&.method_defined?(:__orig_configured?)
  end

  test "disconnect from settings returns to settings" do
    grant_social_admin!
    page = nil
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.create!(
        owner: @user, provider: :facebook, external_id: "111", name: "Youth Page",
        access_token: "page-secret-token", status: :active
      )
    end
    sign_in @user
    delete social_connection_path(page), headers: { "HTTP_REFERER" => account_settings_url }
    assert_redirected_to account_settings_url
    ActsAsTenant.with_tenant(@org) do
      assert page.reload.connection_disconnected?
      assert_nil page.access_token
    end
  end

  test "a teammate can see a connected page but cannot connect or disconnect it" do
    manager_role = Role.create!(name: "Manager", slug: "manager-#{SecureRandom.hex(4)}")
    manager_role.role_permissions.create!(module_name: "social_media", access_level: "write")
    manager = User.create!(organization: @org, role: manager_role, name: "Mina",
                           email: "mina-#{SecureRandom.hex(4)}@example.com", password: "password123")
    ActsAsTenant.with_tenant(@org) do
      SocialMedia::SocialPage.create!(
        owner: @user, provider: :instagram, external_id: "ig-9", name: "youth.ig",
        access_token: "page-secret-token", status: :active
      )
    end

    sign_in manager
    get account_settings_path
    assert_response :success
    assert_match "youth.ig", response.body
    assert_match I18n.t("settings.social_read_only"), response.body
    assert_select "form[action='/auth/facebook']", count: 0
    assert_select "button", text: I18n.t("social.disconnect"), count: 0
  end

  test "another organization's page stays off this account" do
    @role.role_permissions.create!(module_name: "social_media", access_level: "write")
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Other Org") }
    ActsAsTenant.with_tenant(other) do
      owner = User.create!(organization: other, role: @role, name: "Other",
                           email: "other-#{SecureRandom.hex(4)}@example.com", password: "password123")
      SocialMedia::SocialPage.create!(
        owner: owner, provider: :facebook, external_id: "999", name: "Secret Page",
        access_token: "secret", status: :active
      )
    end

    sign_in @user
    get account_settings_path
    assert_response :success
    assert_no_match "Secret Page", response.body
  end

  private

  def grant_social_admin!
    role = Role.find_or_create_by!(slug: "org_admin") { |record| record.name = "Org Admin" }
    permission = role.role_permissions.find_or_initialize_by(module_name: "social_media")
    permission.access_level = "write"
    permission.save!
    @user.update!(role: role)
  end
end
