class Booth < ApplicationRecord
  # booth numbers repeat across assemblies/loksabhas, so this is a real catalog row, not a flat int (§6.7).
  belongs_to :village
  has_many :voters, dependent: :nullify
  validates :number, presence: true

  # Roll-cover totals live on the booth. These are the voters actually stored for that booth.
  def voter_gender_counts
    totals = { male: 0, female: 0, others: 0, unspecified: 0 }
    voters.group(:gender).count.each do |gender, count|
      totals[gender_bucket(gender)] += count
    end
    totals
  end

  # `number` is text. Numeric values sort as integers (2 before 10); anything else follows, by the text itself.
  scope :by_number, -> {
    order(
      Arel.sql("CASE WHEN booths.number ~ '^[0-9]+$' THEN booths.number::bigint END ASC NULLS LAST"),
      :number,
      :id
    )
  }

  private

  def gender_bucket(gender)
    case gender.to_s.strip
    when /\A(male|m)\z/i then :male
    when /\A(female|f)\z/i then :female
    when "" then :unspecified
    else :others
    end
  end
end
