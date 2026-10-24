class Booth < ApplicationRecord
  # booth numbers repeat across assemblies/loksabhas, so this is a real catalog row, not a flat int (§6.7).
  belongs_to :village
  has_many :voters, dependent: :nullify
  has_many :booth_managers, class_name: "User", dependent: :nullify
  validates :number, presence: true

  # Roll-cover totals live on the booth. These are the voters actually stored for that booth.
  def voter_gender_counts
    Voter.gender_counts(voters)
  end

  # Elector counts read from roll PDFs and saved on booths. Nil when no booth has them yet.
  def self.elector_totals
    male, female, other, recorded = pick(
      Arel.sql("COALESCE(SUM(male_electors), 0)"),
      Arel.sql("COALESCE(SUM(female_electors), 0)"),
      Arel.sql("COALESCE(SUM(other_electors), 0)"),
      Arel.sql("COUNT(*) FILTER (WHERE male_electors IS NOT NULL OR female_electors IS NOT NULL OR other_electors IS NOT NULL)")
    )
    return if recorded.to_i.zero?

    { male: male.to_i, female: female.to_i, others: other.to_i }
  end

  # `number` is text. Numeric values sort as integers (2 before 10); anything else follows, by the text itself.
  scope :by_number, -> {
    order(
      Arel.sql("CASE WHEN booths.number ~ '^[0-9]+$' THEN booths.number::bigint END ASC NULLS LAST"),
      :number,
      :id
    )
  }
end
