require "test_helper"

class PrRecordTest < ActiveSupport::TestCase
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
      @category = PrCategory.find_by(slug: "electronic") || PrCategory.create!(
        name: "Electronic",
        slug: "electronic",
        active: true,
        display_order: 1
      )
    end
  end

  test "creates pr_record with required fields" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.build(
        owner: @user,
        title: "New Campaign Coverage",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "Local News"
      )
      assert record.save
      assert_equal @org.id, record.organization_id
      assert_equal @user.id, record.owner_id
    end
  end

  test "assigns record number in format PR-org_id-5digit" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.build(
        owner: @user,
        title: "Campaign Coverage",
        published_on: Date.today,
        sentiment: :neutral,
        pr_category: @category,
        media_platform_name: "News"
      )
      record.save
      assert_match(/^PR-\d+-\d{5}$/, record.record_number)
      org_id = record.record_number.split("-")[1].to_i
      assert_equal @org.id, org_id
    end
  end

  test "increments record number sequence per organization" do
    ActsAsTenant.with_tenant(@org) do
      record1 = @org.pr_records.create!(
        owner: @user,
        title: "Coverage 1",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "News"
      )

      record2 = @org.pr_records.create!(
        owner: @user,
        title: "Coverage 2",
        published_on: Date.today,
        sentiment: :neutral,
        pr_category: @category,
        media_platform_name: "News"
      )

      seq1 = record1.record_number.split("-").last.to_i
      seq2 = record2.record_number.split("-").last.to_i
      assert seq2 > seq1
    end
  end

  test "validates media platform present via either fk or free text" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.build(
        owner: @user,
        title: "Campaign",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category
      )
      assert_not record.save
      assert_includes record.errors.full_messages.join.downcase, "media"
    end
  end

  test "accepts media platform FK when present" do
    ActsAsTenant.with_tenant(@org) do
      platform = MediaPlatform.create!(name: "TV News", slug: "tv-news", active: true)
      record = @org.pr_records.build(
        owner: @user,
        title: "Campaign",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform: platform
      )
      assert record.save
    end
  end

  test "accepts media platform free text when no FK" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.build(
        owner: @user,
        title: "Campaign",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "Local Radio 104.5"
      )
      assert record.save
    end
  end

  test "soft delete discards record" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.create!(
        owner: @user,
        title: "Coverage",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "News"
      )
      assert_nil record.discarded_at

      record.discard
      assert_not_nil record.discarded_at
      assert_includes PrRecord.discarded, record
      assert_not_includes PrRecord.kept, record
    end
  end

  test "sentiment enum has correct values" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.create!(
        owner: @user,
        title: "Test",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "News"
      )
      assert_equal "positive", record.sentiment
      assert record.positive?
    end
  end

  test "scoped to organization via acts_as_tenant" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.create!(
        owner: @user,
        title: "Org Record",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "News"
      )

      other_org = ActsAsTenant.without_tenant { Organization.create!(name: "Other Org") }

      ActsAsTenant.with_tenant(other_org) do
        assert_not_includes PrRecord.all, record
      end
    end
  end

  test "unique constraint on organization_id and record_number" do
    ActsAsTenant.with_tenant(@org) do
      record1 = @org.pr_records.create!(
        owner: @user,
        title: "Coverage 1",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "News"
      )

      record2 = @org.pr_records.build(
        owner: @user,
        title: "Coverage 2",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "News"
      )
      record2.record_number = record1.record_number

      assert_raises ActiveRecord::RecordNotUnique do
        record2.save!(validate: false)
      end
    end
  end

  test "belongs to organization" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.build(
        owner: @user,
        title: "Test",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "News"
      )
      assert_equal @org, record.organization
    end
  end

  test "belongs to owner user" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.create!(
        owner: @user,
        title: "Test",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "News"
      )
      assert_equal @user, record.owner
    end
  end

  test "belongs to pr_category" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.create!(
        owner: @user,
        title: "Test",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "News"
      )
      assert_equal @category, record.pr_category
    end
  end
end
