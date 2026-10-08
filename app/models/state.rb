class State < ApplicationRecord
  # Global geography reference data (§6.3b) — NOT tenant-scoped, Admin-managed.
  has_many :loksabhas, dependent: :restrict_with_error
  has_many :voters, dependent: :restrict_with_error
  validates :name, presence: true
end
