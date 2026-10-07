require "test_helper"

# Story 4.1 — PR catalogs (pr_categories, media_platforms, outdoor_ad_types) CRUD.
class ConsolePrCatalogsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    ActsAsTenant.without_tenant do
      @admin = Admin.create!(name: "Admin", email: "admin@example.com", password: "password123", tier: :full)
    end
  end

  test "admin can manage PR categories" do
    sign_in @admin
    get console_pr_categories_path
    assert_response :success
    assert_select "h1", text: "PR Categories"
  end

  test "admin can create a PR category" do
    sign_in @admin
    post console_pr_categories_path,
      params: { record: { name: "Test Category", slug: "test-category", display_order: 99, active: true } }
    assert_response :redirect
    assert PrCategory.find_by(slug: "test-category")
  end

  test "admin can edit a PR category" do
    PrCategory.create!(name: "Original", slug: "original", display_order: 1, active: true)
    sign_in @admin
    cat = PrCategory.find_by(slug: "original")
    patch console_pr_category_path(cat), params: { record: { name: "Updated", active: false } }
    assert_response :redirect
    cat.reload
    assert_equal "Updated", cat.name
    assert !cat.active
  end

  test "admin can delete a PR category" do
    cat = PrCategory.create!(name: "Delete Me", slug: "delete-me", display_order: 1, active: true)
    sign_in @admin
    delete console_pr_category_path(cat)
    assert_response :redirect
    assert_not PrCategory.exists?(cat.id)
  end

  test "admin can manage media platforms" do
    sign_in @admin
    get console_media_platforms_path
    assert_response :success
    assert_select "h1", text: "Media Platforms"
  end

  test "admin can create a media platform" do
    sign_in @admin
    post console_media_platforms_path,
      params: { record: { name: "Television", slug: "television", active: true } }
    assert_response :redirect
    assert MediaPlatform.find_by(slug: "television")
  end

  test "admin can manage outdoor ad types" do
    sign_in @admin
    get console_outdoor_ad_types_path
    assert_response :success
    assert_select "h1", text: "Outdoor Ad Types"
  end

  test "admin can create an outdoor ad type" do
    sign_in @admin
    post console_outdoor_ad_types_path,
      params: { record: { name: "Billboard", slug: "billboard", active: true } }
    assert_response :redirect
    assert OutdoorAdType.find_by(slug: "billboard")
  end

  test "unauthenticated cannot access PR catalogs" do
    get console_pr_categories_path
    assert_redirected_to new_admin_session_path
  end
end
