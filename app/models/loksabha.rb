class Loksabha < ApplicationRecord
  belongs_to :state
  has_many :assemblies, dependent: :restrict_with_error
  validates :name, presence: true
end
