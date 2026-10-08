class District < ApplicationRecord
  belongs_to :state
  has_many :talukas, dependent: :restrict_with_error
  has_many :loksabhas, dependent: :restrict_with_error

  validates :name, presence: true
end
