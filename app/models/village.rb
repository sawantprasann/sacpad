class Village < ApplicationRecord
  belongs_to :assembly
  has_many :booths, dependent: :restrict_with_error
  validates :name, presence: true
end
