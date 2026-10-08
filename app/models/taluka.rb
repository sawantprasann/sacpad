class Taluka < ApplicationRecord
  belongs_to :district
  has_many :villages, dependent: :restrict_with_error

  validates :name, presence: true
end
