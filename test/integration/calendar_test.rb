require "test_helper"

class CalendarTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Calendar Org") }
    @role = Role.find_or_create_by!(slug: "pa") { |role| role.name = "PA" }
    @user = User.create!(organization: @org, role: @role, name: "Asha", email: "asha-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @other = User.create!(organization: @org, role: @role, name: "Nia", email: "nia-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @today = CalendarEvent.zone.today
  end

  test "guests are sent to sign in" do
    get calendar_events_path
    assert_redirected_to new_user_session_path
  end

  test "only a PA or org admin sees the calendar" do
    sign_in @user
    get root_path
    assert_select "a[href='#{calendar_events_path}']", text: I18n.t("nav.calendar")

    admin_role = Role.find_or_create_by!(slug: "org_admin") { |role| role.name = "Org Admin" }
    admin = User.create!(organization: @org, role: admin_role, name: "Meera", email: "meera-#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in admin
    get root_path
    assert_select "a[href='#{calendar_events_path}']", text: I18n.t("nav.calendar")

    karyakarta = Role.create!(name: "Karyakarta", slug: "karyakarta-#{SecureRandom.hex(4)}")
    outsider = User.create!(organization: @org, role: karyakarta, name: "Ravi", email: "ravi-#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in outsider
    get root_path
    assert_select "a[href='#{calendar_events_path}']", text: I18n.t("nav.calendar"), count: 0
    assert_select "#home-schedule-heading", count: 0

    get calendar_events_path
    assert_redirected_to root_path
    assert_equal I18n.t("calendar.no_access"), flash[:alert]
  end

  test "the calendar opens on the current month and accepts a new event" do
    sign_in @user
    get calendar_events_path

    assert_response :success
    assert_match I18n.l(@today.beginning_of_month, format: "%B %Y"), response.body
    assert_match I18n.t("date.abbr_day_names").first, response.body
    assert_select "a[href='#{calendar_events_path}']", text: /Calendar/
    assert_select "a[href='#{calendar_events_path(month: @today.beginning_of_month.prev_month.strftime("%Y-%m"))}']"

    post calendar_events_path, params: {
      month: @today.strftime("%Y-%m"),
      calendar_event: {
        title: "Ward meeting",
        color: "success",
        starts_on: @today.iso8601,
        starts_time: "15:30",
        ends_on: @today.iso8601,
        ends_time: "16:00",
        location: "Indapur office"
      }
    }
    assert_redirected_to calendar_events_path(month: @today.strftime("%Y-%m"))
    follow_redirect!
    assert_match "Event added to your calendar.", response.body
    assert_match "Ward meeting", response.body
    assert_match "3:30 PM", response.body

    get root_path
    assert_select "#schedule-today", text: /Ward meeting/
    assert_select "#schedule-today", text: /Indapur office/
    assert_select "#schedule-tomorrow", text: /Ward meeting/, count: 0
  end

  test "tomorrow's appointment stays on tomorrow" do
    tomorrow = @today + 1
    sign_in @user
    post calendar_events_path, params: {
      calendar_event: {
        title: "Morning rally",
        color: "warning",
        starts_on: tomorrow.iso8601,
        starts_time: "08:00",
        ends_on: tomorrow.iso8601,
        ends_time: "09:00"
      }
    }
    follow_redirect!

    get root_path
    assert_select "#schedule-tomorrow", text: /Morning rally/
    assert_select "#schedule-today", text: /Morning rally/, count: 0
  end

  test "a user only sees and edits their own events" do
    event = ActsAsTenant.with_tenant(@org) do
      @user.calendar_events.create!(
        organization: @org,
        title: "Private meeting",
        color: "primary",
        starts_on: @today.iso8601,
        starts_time: "11:00",
        ends_on: @today.iso8601,
        ends_time: "12:00"
      )
    end

    sign_in @other
    get calendar_events_path(month: @today.strftime("%Y-%m"), edit: event.id)
    assert_response :success
    assert_no_match "Private meeting", response.body

    get root_path
    assert_no_match "Private meeting", response.body

    patch calendar_event_path(event), params: {
      calendar_event: { title: "Taken over", color: "danger", starts_on: @today.iso8601, starts_time: "11:00", ends_on: @today.iso8601, ends_time: "12:00" }
    }
    assert_response :not_found

    delete calendar_event_path(event)
    assert_response :not_found
    assert_equal "Private meeting", ActsAsTenant.with_tenant(@org) { event.reload.title }
  end

  test "the owner can rename and remove an event" do
    sign_in @user
    post calendar_events_path, params: {
      calendar_event: {
        title: "Lane meeting",
        color: "primary",
        starts_on: @today.iso8601,
        starts_time: "09:00",
        ends_on: @today.iso8601,
        ends_time: "10:00"
      }
    }
    event = ActsAsTenant.with_tenant(@org) { @user.calendar_events.find_by!(title: "Lane meeting") }

    get calendar_events_path(month: @today.strftime("%Y-%m"), edit: event.id)
    assert_select "input[name='calendar_event[title]'][value='Lane meeting']"

    patch calendar_event_path(event), params: {
      calendar_event: {
        title: "Updated visit",
        color: "primary",
        starts_on: @today.iso8601,
        starts_time: "09:00",
        ends_on: @today.iso8601,
        ends_time: "10:30"
      }
    }
    assert_redirected_to calendar_events_path(month: @today.strftime("%Y-%m"))
    follow_redirect!
    assert_match "Updated visit", response.body
    assert_no_match("Lane meeting", response.body)

    delete calendar_event_path(event)
    assert_redirected_to calendar_events_path(month: @today.strftime("%Y-%m"))
    follow_redirect!
    assert_match "Event removed.", response.body
    assert_no_match "Updated visit", response.body
  end

  test "an end time before the start is rejected" do
    sign_in @user
    post calendar_events_path, params: {
      calendar_event: {
        title: "Backwards",
        color: "danger",
        starts_on: @today.iso8601,
        starts_time: "15:00",
        ends_on: @today.iso8601,
        ends_time: "14:00"
      }
    }
    assert_response :unprocessable_entity
    assert_match "End must be after the start.", response.body
    assert_equal 0, ActsAsTenant.with_tenant(@org) { @user.calendar_events.count }
  end

  test "a bad month parameter still opens the current month" do
    sign_in @user
    get calendar_events_path(month: "2026-13")
    assert_response :success
    assert_match I18n.l(@today.beginning_of_month, format: "%B %Y"), response.body

    get calendar_events_path(month: "nope")
    assert_response :success
  end
end
