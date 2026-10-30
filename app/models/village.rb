class Village < ApplicationRecord
  include NativeNamed

  belongs_to :assembly
  belongs_to :taluka, optional: true
  # police_station stays a string until a later migration drops it.
  belongs_to :police_station_record,
    class_name: "PoliceStation",
    foreign_key: :police_station_id,
    optional: true,
    inverse_of: :villages
  has_many :booths, -> { by_number }, dependent: :restrict_with_error
  has_many :voters, dependent: :restrict_with_error
  has_many :ground_reports, class_name: "GroundReports::GroundReport", dependent: :restrict_with_error
  has_many :worship_places, class_name: "GroundReports::WorshipPlace", dependent: :restrict_with_error
  has_one :village_yatra, class_name: "GroundReports::VillageYatra", dependent: :restrict_with_error
  has_many :political_positions, class_name: "GroundReports::VillagePoliticalPosition", dependent: :restrict_with_error
  has_many :local_karyakartas, class_name: "GroundReports::VillageLocalKaryakarta", dependent: :restrict_with_error
  has_many :village_works, class_name: "GroundReports::VillageWork", dependent: :restrict_with_error
  has_many :local_admin_contacts, class_name: "GroundReports::VillageLocalAdminContact", dependent: :restrict_with_error
  has_many :mock_poll_responses, class_name: "GroundReports::MockPollResponse", dependent: :restrict_with_error
  validates :name, presence: true

  before_validation :sync_police_station_record

  def resolved_native_locale
    assembly&.loksabha&.native_locale
  end

  # The string column stays English. The linked station carries the native spelling.
  def police_station_display_name
    police_station_record&.display_name.presence || self[:police_station].presence
  end

  private

  def sync_police_station_record
    return unless will_save_change_to_police_station? || (self[:police_station].present? && police_station_id.nil?)

    cleaned = self[:police_station].to_s.strip
    if cleaned.blank?
      self[:police_station] = nil
      self.police_station_id = nil
      return
    end

    state = assembly&.loksabha&.state
    return if state.blank?

    station = PoliceStation.fetch_or_create!(state: state, name: cleaned)
    self.police_station_record = station
    self[:police_station] = station.name
  end
end
