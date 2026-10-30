module CalendarHelper
  CHIP_CLASSES = {
    "primary" => "border-l-brand-500 bg-brand-50 text-brand-800 dark:bg-brand-500/15 dark:text-brand-100",
    "success" => "border-l-success-500 bg-success-50 text-success-800 dark:bg-success-500/15 dark:text-success-100",
    "warning" => "border-l-warning-500 bg-warning-50 text-warning-800 dark:bg-warning-500/15 dark:text-warning-100",
    "danger" => "border-l-error-500 bg-error-50 text-error-800 dark:bg-error-500/15 dark:text-error-100"
  }.freeze

  DOT_CLASSES = {
    "primary" => "bg-brand-500",
    "success" => "bg-success-500",
    "warning" => "bg-warning-500",
    "danger" => "bg-error-500"
  }.freeze

  SWATCH_CLASSES = {
    "danger" => "has-[:checked]:bg-error-50 has-[:checked]:ring-error-300 dark:has-[:checked]:bg-error-500/10",
    "success" => "has-[:checked]:bg-success-50 has-[:checked]:ring-success-300 dark:has-[:checked]:bg-success-500/10",
    "primary" => "has-[:checked]:bg-brand-50 has-[:checked]:ring-brand-300 dark:has-[:checked]:bg-brand-500/10",
    "warning" => "has-[:checked]:bg-warning-50 has-[:checked]:ring-warning-300 dark:has-[:checked]:bg-warning-500/10"
  }.freeze

  def calendar_chip_class(color)
    CHIP_CLASSES.fetch(color.to_s, CHIP_CLASSES["primary"])
  end

  def calendar_dot_class(color)
    DOT_CLASSES.fetch(color.to_s, DOT_CLASSES["primary"])
  end

  def calendar_swatch_class(color)
    SWATCH_CLASSES.fetch(color.to_s, SWATCH_CLASSES["primary"])
  end

  def calendar_color_choices
    CalendarEvent::COLORS
  end

  def calendar_event_payload(event)
    zone = CalendarEvent.zone
    starts = event.starts_at.in_time_zone(zone)
    ends = event.ends_at.in_time_zone(zone)
    {
      url: calendar_event_path(event),
      title: event.title,
      color: event.color,
      startsOn: starts.strftime("%Y-%m-%d"),
      startsTime: starts.strftime("%H:%M"),
      endsOn: ends.strftime("%Y-%m-%d"),
      endsTime: ends.strftime("%H:%M"),
      location: event.location.to_s,
      notes: event.notes.to_s
    }
  end

  def calendar_clock(time)
    time.in_time_zone(CalendarEvent.zone).strftime("%-I:%M %p")
  end

  def calendar_time_range(event)
    zone = CalendarEvent.zone
    starts = event.starts_at.in_time_zone(zone)
    ends = event.ends_at.in_time_zone(zone)
    left = starts.strftime("%-I:%M %p")
    right = ends.strftime("%-I:%M %p")
    return "#{left} – #{right}" if starts.to_date == ends.to_date

    "#{left} – #{ends.strftime("%-d %b")}, #{right}"
  end

  def calendar_month_token(date)
    date.strftime("%Y-%m")
  end
end
