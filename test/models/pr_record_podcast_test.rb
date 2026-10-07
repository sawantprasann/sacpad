require "test_helper"

class PrRecordPodcastTest < ActiveSupport::TestCase
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
      @category = PrCategory.find_by(slug: "podcasts-interviews") || PrCategory.create!(
        name: "Podcasts/Interviews",
        slug: "podcasts-interviews",
        active: true,
        display_order: 1
      )
      @record = @org.pr_records.create!(
        owner: @user,
        title: "Podcast Feature",
        published_on: Date.today,
        sentiment: :positive,
        pr_category: @category,
        media_platform_name: "News Daily Pod"
      )
    end
  end

  test "creates podcast with recording date" do
    ActsAsTenant.with_tenant(@org) do
      podcast = @record.build_podcast(recording_date: 2.days.ago.to_date)
      assert podcast.save
    end
  end

  test "validates recording date is present" do
    ActsAsTenant.with_tenant(@org) do
      podcast = @record.build_podcast
      assert_not podcast.save
      assert_includes podcast.errors.full_messages.join, "Recording date"
    end
  end

  test "has_one podcast association with dependent destroy" do
    ActsAsTenant.with_tenant(@org) do
      podcast = @record.create_podcast!(recording_date: 1.day.ago.to_date)
      podcast_id = podcast.id

      @record.destroy
      assert_raises(ActiveRecord::RecordNotFound) do
        PrRecordPodcast.find(podcast_id)
      end
    end
  end

  test "belongs to pr_record" do
    ActsAsTenant.with_tenant(@org) do
      podcast = @record.create_podcast!(recording_date: Date.today)
      assert_equal @record, podcast.pr_record
    end
  end

  test "recording date can differ from published_on" do
    ActsAsTenant.with_tenant(@org) do
      podcast = @record.create_podcast!(recording_date: 7.days.ago.to_date)
      assert_not_equal @record.published_on, podcast.recording_date
      assert_equal 7.days.ago.to_date, podcast.recording_date
    end
  end
end
