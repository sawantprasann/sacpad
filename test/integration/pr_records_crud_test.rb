require "test_helper"

# Integration tests for PR Records CRUD — comprehensive tests covering
# org-scoping, policy authorization, and cross-org isolation

class PrRecordsCrudTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Test Org") }
    ActsAsTenant.with_tenant(@org) do
      # Create roles with PR access
      @member_role = Role.create!(
        name: "Member",
        slug: "member-#{Time.current.to_i}"
      )
      @member_role.role_permissions.create!(
        module_name: "pr",
        access_level: "write"
      )

      @admin_role = Role.create!(
        name: "Org Admin",
        slug: "org_admin-#{Time.current.to_i}"
      )
      @admin_role.role_permissions.create!(
        module_name: "pr",
        access_level: "write"
      )

      @user = User.create!(
        organization: @org,
        email: "user@example.com",
        password: "password",
        name: "Test User",
        role: @member_role
      )

      @admin = User.create!(
        organization: @org,
        email: "admin@example.com",
        password: "password",
        name: "Admin User",
        role: @admin_role
      )

      @category = PrCategory.find_by(slug: "electronic") || PrCategory.create!(
        name: "Electronic",
        slug: "electronic",
        active: true,
        display_order: 1
      )

      @platform = MediaPlatform.create!(name: "TV News", slug: "tv-news", active: true)
    end

    sign_in @user
  end

  test "authenticated user can view index" do
    get pr_records_path
    assert_response :success
  end

  test "unauthenticated user redirected" do
    sign_out @user
    get pr_records_path
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "user without pr access is denied" do
    restricted_user = nil
    ActsAsTenant.with_tenant(@org) do
      restricted_role = Role.create!(name: "Restricted", slug: "restricted-#{Time.current.to_i}")
      restricted_user = User.create!(
        organization: @org,
        email: "restricted@example.com",
        password: "password",
        name: "Restricted User",
        role: restricted_role
      )
    end

    sign_out @user
    sign_in restricted_user
    get pr_records_path
    # Users without PR access are redirected to root
    assert_response :redirect
    assert_redirected_to root_path
  end

  test "index with category filter" do
    ActsAsTenant.with_tenant(@org) do
      @org.pr_records.create!(
        owner: @user,
        title: "Electronic Coverage",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform: @platform
      )
    end

    get pr_records_path(category: @category.slug)
    assert_response :success
  end

  test "user can create record with owner set to current_user" do
    ActsAsTenant.with_tenant(@org) do
      post pr_records_path, params: {
        pr_record: {
          title: "New Coverage",
          published_on: Date.today,
          sentiment: "positive",
          pr_category_id: @category.id,
          media_platform_id: @platform.id,
          description: "Test coverage"
        }
      }

      assert_response :redirect
      record = PrRecord.kept.order(created_at: :desc).first
      assert_equal @user.id, record.owner_id
      assert_equal "New Coverage", record.title
    end
  end

  test "media platform validation prevents invalid submission" do
    ActsAsTenant.with_tenant(@org) do
      post pr_records_path, params: {
        pr_record: {
          title: "Missing Platform",
          published_on: Date.today,
          sentiment: "positive",
          pr_category_id: @category.id
          # Missing both media_platform_id and media_platform_name
        }
      }

      # Validation fails, returns form with errors
      assert_response :unprocessable_entity
    end
  end

  test "user can view their own record" do
    record = nil
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.create!(
        owner: @user,
        title: "My Record",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform: @platform
      )
    end

    get pr_record_path(record)
    assert_response :success
    assert_match "My Record", @response.body
  end

  test "user cannot view unrelated user's record (subtree restricted)" do
    other_user = nil
    record = nil
    ActsAsTenant.with_tenant(@org) do
      other_user = User.create!(
        organization: @org,
        email: "other@example.com",
        password: "password",
        name: "Other User",
        role: @member_role
      )
      record = @org.pr_records.create!(
        owner: other_user,
        title: "Other User Record",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform: @platform
      )
    end

    get pr_record_path(record)
    # Policy scope filters out records outside subtree, resulting in 404
    assert_response 404
  end

  # Org admin elevation is tested at policy layer via policy_scope and authorize checks.
  # Integration test would require proper tenant context throughout sign_in/sign_out transitions.

  test "cross-org isolation prevents access" do
    other_org = ActsAsTenant.without_tenant { Organization.create!(name: "Other Org") }
    other_record = nil

    ActsAsTenant.with_tenant(other_org) do
      role = Role.create!(
        name: "Member",
        slug: "member-other-#{Time.current.to_i}"
      )
      user = User.create!(
        organization: other_org,
        email: "other-org@example.com",
        password: "password",
        name: "Other Org User",
        role: role
      )
      category = PrCategory.find_or_create_by(slug: "electronic") do |c|
        c.name = "Electronic"
        c.active = true
      end
      platform = MediaPlatform.find_or_create_by(slug: "tv-news") do |p|
        p.name = "TV News"
        p.active = true
      end

      other_record = other_org.pr_records.create!(
        owner: user,
        title: "Other Org Record",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: category,
        media_platform: platform
      )
    end

    # Current user from @org tries to access @other_org's record
    get pr_record_path(other_record)
    assert_response 404
  end
end
