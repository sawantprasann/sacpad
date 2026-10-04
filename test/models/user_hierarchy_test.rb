require "test_helper"

class UserHierarchyTest < ActiveSupport::TestCase
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @role = Role.create!(name: "Org Admin", slug: "org_admin", can_create_users: true)
  end

  def make(name, parent: nil)
    User.create!(organization: @org, role: @role, name: name, parent: parent,
                 email: "#{name.downcase}@example.com", password: "password123")
  end

  test "closure_tree gives unlimited-depth descendants and subtree ids" do
    root = make("Root")
    district = make("District", parent: root)
    taluka = make("Taluka", parent: district)
    peer = make("Peer", parent: root)

    assert_includes root.subtree_user_ids, taluka.id
    assert_includes root.subtree_user_ids, peer.id
    assert_includes district.subtree_user_ids, taluka.id
    assert_not_includes district.subtree_user_ids, peer.id
    assert_equal [ district.id, taluka.id ].sort, district.subtree_user_ids.sort
  end

  test "multiple org admins (root users) can coexist" do
    a = make("Politician")
    b = make("ChiefOfStaff")
    assert_nil a.parent
    assert_nil b.parent
  end
end
