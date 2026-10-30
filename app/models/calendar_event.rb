class CalendarEvent < ApplicationRecord
  # The app time zone is UTC. Schedules are kept in India Standard Time so a
  # 9:00 AM appointment stays on that calendar day.
  ZONE_NAME = "Asia/Kolkata"
  COLORS = %w[danger success primary warning].freeze

  include OrganizationScoped

  belongs_to :user

  validates :title, presence: true, length: { maximum: 140 }
  validates :starts_at, :ends_at, presence: true, unless: :parts_submitted?
  validates :color, inclusion: { in: COLORS }
  validates :location, length: { maximum: 160 }, allow_nil: true
  validates :notes, length: { maximum: 2000 }, allow_nil: true
  validate :times_make_sense

  before_validation :normalize_fields
  before_validation :assign_times_from_parts

  scope :chronological, -> { order(:starts_at, :id) }

  def self.zone
    Time.find_zone!(ZONE_NAME)
  end

  def self.covering(from_time, to_time)
    where(arel_table[:starts_at].lt(to_time)).where(arel_table[:ends_at].gt(from_time))
  end

  def self.on_date(date)
    day = date.to_date
    from = zone.local(day.year, day.month, day.day)
    covering(from, from + 1.day)
  end

  def occurs_on?(date)
    day = date.to_date
    from = self.class.zone.local(day.year, day.month, day.day)
    starts_at.present? && ends_at.present? && starts_at < (from + 1.day) && ends_at > from
  end

  def starting_on?(date)
    starts_at.present? && starts_at.in_time_zone(self.class.zone).to_date == date.to_date
  end

  def starts_on
    return @starts_on if @starts_on.present?

    local_stamp(starts_at)&.strftime("%Y-%m-%d")
  end

  def starts_time
    return @starts_time if @starts_time.present?

    local_stamp(starts_at)&.strftime("%H:%M")
  end

  def ends_on
    return @ends_on if @ends_on.present?

    local_stamp(ends_at)&.strftime("%Y-%m-%d")
  end

  def ends_time
    return @ends_time if @ends_time.present?

    local_stamp(ends_at)&.strftime("%H:%M")
  end

  def starts_on=(value)
    @starts_on = value.presence
  end

  def starts_time=(value)
    @starts_time = value.presence
  end

  def ends_on=(value)
    @ends_on = value.presence
  end

  def ends_time=(value)
    @ends_time = value.presence
  end

  private

  def local_stamp(time)
    time&.in_time_zone(self.class.zone)
  end

  def parts_submitted?
    defined?(@starts_on) || defined?(@starts_time) || defined?(@ends_on) || defined?(@ends_time)
  end

  def normalize_fields
    self.title = title.to_s.strip
    self.location = location.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
    self.color = "primary" if color.blank?
  end

  def assign_times_from_parts
    return unless parts_submitted?

    self.starts_at = compose(@starts_on, @starts_time)
    self.ends_at = compose(@ends_on, @ends_time)
  end

  def compose(date_str, time_str)
    return if date_str.blank? || time_str.blank?
    return unless date_str.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    return unless time_str.to_s.match?(/\A([01]?\d|2[0-3]):[0-5]\d(?::[0-5]\d)?\z/)

    date = Date.iso8601(date_str.to_s)
    hour, minute = time_str.split(":").map(&:to_i)
    self.class.zone.local(date.year, date.month, date.day, hour, minute)
  rescue ArgumentError
    nil
  end

  def times_make_sense
    if parts_submitted?
      errors.add(:base, I18n.t("calendar.start_invalid")) if starts_at.blank?
      errors.add(:base, I18n.t("calendar.end_invalid")) if ends_at.blank?
    end
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:base, I18n.t("calendar.ends_after_start"))
  end
end
