require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "is a separate account type: no organization_id/parent_id/role_id, not tenant-scoped" do
    %w[organization_id parent_id role_id].each do |col|
      assert_not Admin.column_names.include?(col), "Admin must not have #{col}"
    end
    assert_not Admin.ancestors.include?(OrganizationScoped), "Admin must not be tenant-scoped"
  end

  test "tier enum exposes full and ops and defaults to full" do
    assert Admin.tiers.key?("full")
    assert Admin.tiers.key?("ops")
    assert_equal "full", Admin.new.tier
  end

  test "an inactive admin cannot authenticate" do
    assert_not Admin.new(active: false).active_for_authentication?
    assert Admin.new(active: true).active_for_authentication?
  end

  test "does not expose recoverable (no self-service reset)" do
    assert_not Admin.column_names.include?("reset_password_token")
  end
end
