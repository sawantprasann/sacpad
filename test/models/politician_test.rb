require "test_helper"

class PoliticianTest < ActiveSupport::TestCase
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Candidate A") }
  end

  test "is org-scoped (tenant-isolated)" do
    assert Politician.ancestors.include?(OrganizationScoped)
  end

  test "at most one own-candidate per organization" do
    ActsAsTenant.with_tenant(@org) do
      Politician.create!(name: "A", is_own_politician: true)
      dup = Politician.new(name: "B", is_own_politician: true)
      assert_not dup.valid?
      assert_includes dup.errors.attribute_names, :is_own_politician
    end
  end

  test "own-candidate name defaults to and syncs with the organization name" do
    own = ActsAsTenant.with_tenant(@org) { Politician.create!(is_own_politician: true) }
    assert_equal "Candidate A", own.name

    @org.update!(name: "Candidate A (renamed)")
    assert_equal "Candidate A (renamed)", own.reload.name
  end

  test "retiring a politician is a soft delete" do
    admin = Admin.create!(name: "Dev", email: "d@example.com", password: "password123")
    pol = ActsAsTenant.with_tenant(@org) { Politician.create!(name: "Opp") }
    pol.discard_by(admin)
    assert pol.discarded?
    assert_equal admin.id, pol.discarded_by_id
  end
end
