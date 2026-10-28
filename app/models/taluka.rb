class Taluka < ApplicationRecord
  include NativeNamed

  belongs_to :district
  has_many :villages, dependent: :restrict_with_error

  validates :name, presence: true

  def resolved_native_locale
    district&.resolved_native_locale
  end
end
