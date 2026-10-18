class Booth < ApplicationRecord
  # booth numbers repeat across assemblies/loksabhas, so this is a real catalog row, not a flat int (§6.7).
  belongs_to :village
  has_many :voters, dependent: :nullify
  validates :number, presence: true

  # `number` is text. Numeric values sort as integers (2 before 10); anything else follows, by the text itself.
  scope :by_number, -> {
    order(
      Arel.sql("CASE WHEN booths.number ~ '^[0-9]+$' THEN booths.number::bigint END ASC NULLS LAST"),
      :number,
      :id
    )
  }
end
