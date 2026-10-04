require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @role = Role.create!(name: "Org Admin", slug: "org_admin", can_create_users: true)
  end

  def build_user(**attrs)
    User.new({ organization: @org, role: @role, name: "Rohan",
               email: "rohan@example.com", password: "password123" }.merge(attrs))
  end

  test "belongs to organization and role; parent optional with children" do
    head = build_user(email: "head@example.com", name: "Head")
    head.save!
    child = build_user(email: "child@example.com", name: "Child", parent: head)
    child.save!
    assert_includes head.children, child
    assert_equal @org, child.organization
  end

  test "User is NOT acts_as_tenant (account model queried by email without tenant)" do
    assert_not User.ancestors.include?(OrganizationScoped)
    build_user.save!
    # No tenant set here; a non-tenant-scoped query must NOT raise.
    assert_nothing_raised { User.find_by(email: "rohan@example.com") }
  end

  test "email is globally unique" do
    build_user.save!
    dup = build_user
    assert_not dup.valid?
    assert_includes dup.errors.attribute_names, :email
  end

  test "an inactive user cannot authenticate" do
    assert_not build_user(active: false).active_for_authentication?
    assert build_user(active: true).active_for_authentication?
  end
end
