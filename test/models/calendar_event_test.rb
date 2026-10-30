require "test_helper"

class CalendarEventTest < ActiveSupport::TestCase
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Calendar Org") }
    @role = Role.create!(name: "Calendar", slug: "calendar-#{SecureRandom.hex(4)}")
    @user = User.create!(organization: @org, role: @role, name: "Asha", email: "asha-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @other = User.create!(organization: @org, role: @role, name: "Nia", email: "nia-#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  test "stores the chosen clock time in India Standard Time" do
    event = create_event(starts_on: "2026-10-30", starts_time: "09:30", ends_on: "2026-10-30", ends_time: "10:15")

    zone = CalendarEvent.zone
    assert_equal zone.local(2026, 10, 30, 9, 30), event.starts_at
    assert_equal zone.local(2026, 10, 30, 10, 15), event.ends_at
    assert_equal "2026-10-30", event.starts_on
    assert_equal "09:30", event.starts_time
  end

  test "a late evening event stays on that calendar day" do
    late = create_event(title: "Late", starts_on: "2026-10-30", starts_time: "23:30", ends_on: "2026-10-30", ends_time: "23:45")
    early = create_event(title: "Early", starts_on: "2026-10-31", starts_time: "00:15", ends_on: "2026-10-31", ends_time: "00:45")

    assert_includes events_on(@user, Date.new(2026, 10, 30)), late
    assert_not_includes events_on(@user, Date.new(2026, 10, 31)), late
    assert_includes events_on(@user, Date.new(2026, 10, 31)), early
    assert_not_includes events_on(@user, Date.new(2026, 10, 30)), early
  end

  test "an event that crosses midnight appears on both days" do
    event = create_event(title: "Overnight", starts_on: "2026-10-30", starts_time: "22:00", ends_on: "2026-10-31", ends_time: "01:00")

    assert event.occurs_on?(Date.new(2026, 10, 30))
    assert event.occurs_on?(Date.new(2026, 10, 31))
    assert event.starting_on?(Date.new(2026, 10, 30))
    assert_not event.starting_on?(Date.new(2026, 10, 31))
  end

  test "another user does not see the event" do
    event = create_event(title: "Private")

    assert_includes events_on(@user, Date.new(2026, 10, 30)), event
    assert_not_includes events_on(@other, Date.new(2026, 10, 30)), event
  end

  test "rejects a blank title, an unknown color, and an end before the start" do
    ActsAsTenant.with_tenant(@org) do
      blank = @user.calendar_events.new(organization: @org, color: "primary", starts_on: "2026-10-30", starts_time: "09:00", ends_on: "2026-10-30", ends_time: "10:00", title: "  ")
      assert_not blank.valid?
      assert blank.errors[:title].any?

      bad_color = @user.calendar_events.new(organization: @org, title: "Visit", color: "nope", starts_on: "2026-10-30", starts_time: "09:00", ends_on: "2026-10-30", ends_time: "10:00")
      assert_not bad_color.valid?
      assert bad_color.errors[:color].any?

      backwards = @user.calendar_events.new(organization: @org, title: "Visit", color: "primary", starts_on: "2026-10-30", starts_time: "11:00", ends_on: "2026-10-30", ends_time: "10:00")
      assert_not backwards.valid?
      assert_includes backwards.errors[:base], I18n.t("calendar.ends_after_start")
    end
  end

  private

  def create_event(attrs = {})
    ActsAsTenant.with_tenant(@org) do
      @user.calendar_events.create!({
        organization: @org,
        title: "Booth visit",
        color: "primary",
        starts_on: "2026-10-30",
        starts_time: "09:00",
        ends_on: "2026-10-30",
        ends_time: "10:00"
      }.merge(attrs))
    end
  end

  def events_on(user, date)
    ActsAsTenant.with_tenant(@org) { user.calendar_events.on_date(date).to_a }
  end
end
