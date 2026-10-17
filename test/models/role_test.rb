require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "roles are global reference data, not tenant-scoped" do
    assert_not Role.ancestors.include?(OrganizationScoped)
  end

  test "seed_system_roles! creates org_admin, the roles under it, and dreamline_user idempotently" do
    assert_difference -> { Role.count }, Role::SYSTEM_ROLES.size do
      Role.seed_system_roles!
    end
    assert_no_difference -> { Role.count } do
      Role.seed_system_roles!
    end

    org_admin = Role.find_by!(slug: "org_admin")
    dreamline = Role.find_by!(slug: "dreamline_user")

    assert org_admin.can_create_users?
    assert_not dreamline.can_create_users?
    assert org_admin.is_system?

    %w[manager pa karyakarta].each do |slug|
      role = Role.find_by!(slug: slug)
      assert role.is_system?, "#{slug} should be a system role"
      assert_not role.can_create_users?, "#{slug} sits under org admin and cannot create users"
    end

    Role::SYSTEM_ROLES.each do |attrs|
      role = Role.find_by!(slug: attrs[:slug])
      expected = attrs[:access] || Role::MODULES.index_with { "write" }
      Role::MODULES.each do |mod|
        assert_equal expected.fetch(mod, "none") == "write", role.can_write?(mod), "#{attrs[:slug]} should #{expected.fetch(mod, "none")} #{mod}"
      end
    end

    booth_manager = Role.find_by!(slug: "booth_manager")
    assert booth_manager.can_write?("voter_lists")
    assert_not booth_manager.can_access?("booth_management")
    assert_not booth_manager.can_access?("ground_reports")
  end

  test "access helpers reflect permission rows" do
    role = Role.create!(name: "PR Manager", slug: "pr_manager")
    role.role_permissions.create!(module_name: "pr", access_level: "write")
    role.role_permissions.create!(module_name: "voter_lists", access_level: "read")

    assert_equal "write", role.access_for("pr")
    assert role.can_write?("pr")
    assert role.can_access?("voter_lists")
    assert_not role.can_write?("voter_lists")
    assert_equal "none", role.access_for("rag_mapping")
    assert_not role.can_access?("rag_mapping")
  end
end
