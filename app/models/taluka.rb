class Taluka < ApplicationRecord
  belongs_to :district
  has_many :assemblies, dependent: :restrict_with_error

  validates :name, presence: true
end
