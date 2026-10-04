class Booth < ApplicationRecord
  # booth numbers repeat across assemblies/loksabhas, so this is a real catalog row, not a flat int (§6.7).
  belongs_to :village
  validates :number, presence: true
end
