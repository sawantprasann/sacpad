class PoliceStation < ApplicationRecord
  include NativeNamed

  belongs_to :state
  has_many :villages, foreign_key: :police_station_id, inverse_of: :police_station_record, dependent: :restrict_with_error

  validates :name, presence: true
  validates :name, uniqueness: { scope: :state_id, case_sensitive: false }

  def self.fetch_or_create!(state:, name:)
    cleaned = name.to_s.strip
    raise ArgumentError, "Police station name is blank" if cleaned.blank?

    find_by_name(state, cleaned) || create!(state: state, name: cleaned)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    found = find_by_name(state, cleaned)
    raise unless found

    found
  end

  # A state uses one native spelling only when every Lok Sabha in it shares one language.
  def resolved_native_locale
    return if state_id.blank?

    locales = Loksabha.where(state_id: state_id).where.not(native_locale: [ nil, "" ]).distinct.pluck(:native_locale)
    locales.first if locales.one?
  end

  def self.find_by_name(state, name)
    where(state_id: state.id).where("lower(name) = ?", name.downcase).first
  end
  private_class_method :find_by_name
end
