class Organization < ApplicationRecord
  # The tenant itself — NOT acts_as_tenant-scoped (it is the scope).
  # Geography/party associations (constituency, parties, politicians) are wired in later
  # stories (0.4/0.5/0.12); constituency is polymorphic + optional for now (§3.1c).
  belongs_to :constituency, polymorphic: true, optional: true

  validates :name, presence: true

  scope :active, -> { where(active: true) }
end
