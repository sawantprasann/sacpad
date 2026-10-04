class Assembly < ApplicationRecord
  belongs_to :loksabha
  has_many :villages, dependent: :restrict_with_error
  validates :name, presence: true
end
