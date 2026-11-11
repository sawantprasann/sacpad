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
      record = build_record(title: "New Campaign Coverage")
      assert record.save
      assert_equal @org.id, record.organization_id
      assert_equal @user.id, record.owner_id
      assert_equal @category, record.entries.first.pr_category
    end
  end

  test "assigns record number in format PR-org_id-5digit" do
    ActsAsTenant.with_tenant(@org) do
      record = build_record(title: "Campaign Coverage")
      record.save
      assert_match(/^PR-\d+-\d{5}$/, record.record_number)
      org_id = record.record_number.split("-")[1].to_i
      assert_equal @org.id, org_id
    end
  end

  test "increments record number sequence per organization" do
    ActsAsTenant.with_tenant(@org) do
      record1 = create_record!(title: "Coverage 1")
      record2 = create_record!(title: "Coverage 2", sentiment: :neutral)

      seq1 = record1.record_number.split("-").last.to_i
      seq2 = record2.record_number.split("-").last.to_i
      assert seq2 > seq1
    end
  end

  test "requires at least one category" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.build(owner: @user, title: "Headline only")
      assert_not record.save
      assert_includes record.errors.full_messages.join, "category"
    end
  end

  test "stores multiple categories under one headline" do
    ActsAsTenant.with_tenant(@org) do
      print = PrCategory.find_by(slug: "print") || PrCategory.create!(
        name: "Print", slug: "print", active: true, display_order: 2
      )
      record = build_record(title: "Shared headline")
      record.entries.build(
        published_on: Date.current,
        sentiment: :neutral,
        pr_category: print,
        media_platform_name: "Lokmat"
      )

      assert record.save
      assert_equal [ "Electronic", "Print" ], record.category_names
      assert_equal "Shared headline", record.title
    end
  end

  test "validates media platform present via either fk or free text" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.build(owner: @user, title: "Campaign")
      record.entries.build(published_on: Date.current, sentiment: :positive, pr_category: @category)
      assert_not record.save
      assert_includes record.errors.full_messages.join.downcase, "media"
    end
  end

  test "accepts media platform FK when present" do
    ActsAsTenant.with_tenant(@org) do
      platform = MediaPlatform.create!(name: "TV News", slug: "tv-news-#{Time.current.to_i}", active: true)
      record = build_record(title: "Campaign", media_platform: platform, media_platform_name: nil)
      assert record.save
    end
  end

  test "accepts media platform free text when no FK" do
    ActsAsTenant.with_tenant(@org) do
      record = build_record(title: "Campaign", media_platform_name: "Local Radio 104.5")
      assert record.save
      assert_equal "Local Radio 104.5", record.entries.first.platform_name
    end
  end

  test "soft delete discards record" do
    ActsAsTenant.with_tenant(@org) do
      record = create_record!(title: "Coverage")
      assert_nil record.discarded_at

      record.discard
      assert_not_nil record.discarded_at
      assert_includes PrRecord.discarded, record
      assert_not_includes PrRecord.kept, record
    end
  end

  test "sentiment enum has correct values" do
    ActsAsTenant.with_tenant(@org) do
      record = create_record!(title: "Test")
      entry = record.entries.first
      assert_equal "positive", entry.sentiment
      assert entry.positive?
    end
  end

  test "scoped to organization via acts_as_tenant" do
    ActsAsTenant.with_tenant(@org) do
      record = create_record!(title: "Org Record")
      other_org = ActsAsTenant.without_tenant { Organization.create!(name: "Other Org") }

      ActsAsTenant.with_tenant(other_org) do
        assert_not_includes PrRecord.all, record
      end
    end
  end

  test "unique constraint on organization_id and record_number" do
    ActsAsTenant.with_tenant(@org) do
      record1 = create_record!(title: "Coverage 1")
      record2 = build_record(title: "Coverage 2")
      record2.record_number = record1.record_number

      assert_raises ActiveRecord::RecordNotUnique do
        record2.save!(validate: false)
      end
    end
  end

  test "belongs to organization" do
    ActsAsTenant.with_tenant(@org) do
      record = build_record(title: "Test")
      assert_equal @org, record.organization
    end
  end

  test "belongs to owner user" do
    ActsAsTenant.with_tenant(@org) do
      record = create_record!(title: "Test")
      assert_equal @user, record.owner
    end
  end

  test "entry belongs to pr_category" do
    ActsAsTenant.with_tenant(@org) do
      record = create_record!(title: "Test")
      assert_equal @category, record.entries.first.pr_category
    end
  end

  private

  def build_record(title:, **entry)
    record = @org.pr_records.build(owner: @user, title: title)
    defaults = {
      published_on: Date.current,
      sentiment: :positive,
      pr_category: @category,
      media_platform_name: "News"
    }
    defaults.delete(:media_platform_name) if entry.key?(:media_platform) && !entry.key?(:media_platform_name)
    record.entries.build(defaults.merge(entry))
    record
  end

  def create_record!(...)
    record = build_record(...)
    record.save!
    record
  end
end
