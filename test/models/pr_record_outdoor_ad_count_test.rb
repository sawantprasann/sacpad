require "test_helper"

class PrRecordOutdoorAdCountTest < ActiveSupport::TestCase
  def setup
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Test Org") }
    ActsAsTenant.with_tenant(@org) do
      role = Role.create!(name: "Member", slug: "member-#{Time.current.to_i}")
      @user = @org.users.create!(
        email: "test@example.com",
        password: "password",
        name: "Test User",
        role: role
      )
      @category = PrCategory.find_by(slug: "outdoor-media") || PrCategory.create!(
        name: "Outdoor Media",
        slug: "outdoor-media",
        active: true,
        display_order: 1
      )
      @ad_type = OutdoorAdType.create!(name: "Billboard", slug: "billboard", active: true)
      @record = @org.pr_records.create!(
        owner: @user,
        title: "Campaign Ads",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "Street Advertising"
      )
    end
  end

  test "creates outdoor ad count with valid attributes" do
    ActsAsTenant.with_tenant(@org) do
      count = @record.outdoor_ad_counts.build(
        outdoor_ad_type: @ad_type,
        count: 5
      )
      assert count.save
    end
  end

  test "validates count is present" do
    ActsAsTenant.with_tenant(@org) do
      count = @record.outdoor_ad_counts.build(outdoor_ad_type: @ad_type)
      assert_not count.save
      assert_includes count.errors.full_messages.join, "Count"
    end
  end

  test "validates count is positive integer" do
    ActsAsTenant.with_tenant(@org) do
      count = @record.outdoor_ad_counts.build(
        outdoor_ad_type: @ad_type,
        count: 0
      )
      assert_not count.save
    end
  end

  test "prevents duplicate ad type per record" do
    ActsAsTenant.with_tenant(@org) do
      @record.outdoor_ad_counts.create!(
        outdoor_ad_type: @ad_type,
        count: 5
      )

      count2 = @record.outdoor_ad_counts.build(
        outdoor_ad_type: @ad_type,
        count: 3
      )
      assert_not count2.save
    end
  end

  test "belongs to pr_record" do
    ActsAsTenant.with_tenant(@org) do
      count = @record.outdoor_ad_counts.create!(
        outdoor_ad_type: @ad_type,
        count: 5
      )
      assert_equal @record, count.pr_record
    end
  end

  test "belongs to outdoor_ad_type" do
    ActsAsTenant.with_tenant(@org) do
      count = @record.outdoor_ad_counts.create!(
        outdoor_ad_type: @ad_type,
        count: 5
      )
      assert_equal @ad_type, count.outdoor_ad_type
    end
  end
end
