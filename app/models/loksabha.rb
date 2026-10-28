class Loksabha < ApplicationRecord
  include NativeNamed

  NATIVE_LOCALES = NativeScript::LOCALES

  belongs_to :state
  belongs_to :district, optional: true
  has_many :assemblies, dependent: :restrict_with_error
  has_many :election_results, class_name: "ConstituencyElection", as: :constituency, inverse_of: :constituency, dependent: :restrict_with_error
  has_many :voters, dependent: :restrict_with_error
  validates :name, presence: true
  validates :native_locale, inclusion: { in: NATIVE_LOCALES }, allow_blank: true

  def resolved_native_locale
    native_locale
  end
end
