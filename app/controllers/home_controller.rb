class HomeController < ApplicationController
  before_action :authenticate_user!

  # The Organization Dashboard (FR50/FR51) — widget-composed, each widget gated by the viewer's
  # role permissions. Unauthenticated visitors are redirected to the (shell-less) sign-in page.
  def index
    @widgets = helpers.dashboard_widgets_for(current_user)
    load_constituency_election
    load_schedule if current_user.can_use_calendar?
  end

  private

  def load_constituency_election
    @constituency_election = ConstituencyElection.for_organization(current_user.organization).first
  end

  def load_schedule
    zone = CalendarEvent.zone
    @schedule_today = zone.today
    @schedule_tomorrow = @schedule_today + 1.day
    @today_events = current_user.calendar_events.on_date(@schedule_today).chronological.to_a
    @tomorrow_events = current_user.calendar_events.on_date(@schedule_tomorrow).chronological.to_a
  end
end
