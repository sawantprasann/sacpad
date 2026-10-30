class District < ApplicationRecord
  include NativeNamed

  belongs_to :state
  has_many :talukas, dependent: :restrict_with_error
  has_many :loksabhas, dependent: :restrict_with_error

  validates :name, presence: true

  # A district uses a native spelling only when every Lok Sabha in it shares one language.
  def resolved_native_locale
    return if new_record?

    locales = loksabhas.where.not(native_locale: [ nil, "" ]).distinct.pluck(:native_locale)
    locales.first if locales.one?
  end
end
