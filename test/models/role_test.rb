require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "roles are global reference data, not tenant-scoped" do
    assert_not Role.ancestors.include?(OrganizationScoped)
  end

  test "seed_system_roles! creates org_admin and dreamline_user idempotently" do
    assert_difference -> { Role.count }, 2 do
      Role.seed_system_roles!
    end
    assert_no_difference -> { Role.count } do
      Role.seed_system_roles!
    end

    org_admin = Role.find_by(slug: "org_admin")
    dreamline = Role.find_by(slug: "dreamline_user")

    assert org_admin.can_create_users?
    assert_not dreamline.can_create_users?
    assert org_admin.is_system?

    Role::MODULES.each do |m|
      assert org_admin.can_write?(m), "org_admin should write #{m}"
      assert dreamline.can_write?(m), "dreamline should write #{m} (v1 full breadth)"
    end
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
