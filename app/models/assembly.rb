class Assembly < ApplicationRecord
  belongs_to :loksabha
  belongs_to :taluka, optional: true
  has_many :villages, dependent: :restrict_with_error
  validates :name, presence: true
end
