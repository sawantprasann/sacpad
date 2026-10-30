class CalendarEventsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_calendar_access
  before_action :set_event, only: %i[update destroy]

  def index
    load_month
    prepare_form
  end

  def create
    @event = current_user.calendar_events.new(event_params)
    @event.organization = current_user.organization
    if @event.save
      redirect_to calendar_events_path(month: month_token(@event.starts_at)), notice: t("calendar.created")
    else
      load_month
      @open_event_form = true
      @open_new_event = false
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @event.update(event_params)
      redirect_to calendar_events_path(month: month_token(@event.starts_at)), notice: t("calendar.updated")
    else
      load_month
      @open_event_form = true
      @open_new_event = false
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    month = month_token(@event.starts_at)
    @event.destroy!
    redirect_to calendar_events_path(month: month), notice: t("calendar.deleted")
  end

  private

  def require_calendar_access
    return if current_user.can_use_calendar?

    redirect_to root_path, alert: t("calendar.no_access")
  end

  def set_event
    @event = current_user.calendar_events.find(params[:id])
  end

  def event_params
    params.require(:calendar_event).permit(
      :title, :color, :starts_on, :starts_time, :ends_on, :ends_time, :location, :notes
    )
  end

  def load_month
    @zone = CalendarEvent.zone
    @today = @zone.today
    @month = parsed_month
    @grid_start = @month.beginning_of_week(:sunday)
    @grid_end = @month.end_of_month.end_of_week(:sunday)
    from = @zone.local(@grid_start.year, @grid_start.month, @grid_start.day)
    to = @zone.local(@grid_end.year, @grid_end.month, @grid_end.day) + 1.day
    @events = current_user.calendar_events.covering(from, to).chronological.to_a
    @events_by_day = Hash.new { |days, day| days[day] = [] }
    @events.each do |event|
      (@grid_start..@grid_end).each do |day|
        @events_by_day[day] << event if event.occurs_on?(day)
      end
    end
  end

  def prepare_form
    @event = CalendarEvent.new(color: "primary")
    seed_blank(@event, parse_iso_date(params[:date]) || @today)
    @open_event_form = false
    if params[:edit].present?
      found = current_user.calendar_events.find_by(id: params[:edit])
      if found
        @event = found
        @open_event_form = true
      end
    end
    @open_new_event = !@open_event_form && params[:new] == "1"
  end

  def seed_blank(event, date)
    event.starts_on = date.iso8601
    event.ends_on = date.iso8601
    event.starts_time = "09:00"
    event.ends_time = "10:00"
  end

  def parsed_month
    raw = params[:month].to_s
    return @today.beginning_of_month unless raw.match?(/\A\d{4}-\d{2}\z/)

    Date.strptime(raw, "%Y-%m")
  rescue ArgumentError
    @today.beginning_of_month
  end

  def parse_iso_date(value)
    return if value.blank?
    return unless value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def month_token(time)
    time.in_time_zone(CalendarEvent.zone).strftime("%Y-%m")
  end
end
