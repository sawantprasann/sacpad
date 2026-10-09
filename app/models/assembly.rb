class Assembly < ApplicationRecord
  belongs_to :loksabha
  has_many :villages, dependent: :restrict_with_error
  has_many :voters, dependent: :restrict_with_error
  validates :name, presence: true
  validates :first_part, :last_part, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :part_range_order

  private

  def part_range_order
    return if first_part.blank? && last_part.blank?

    if first_part.blank? || last_part.blank?
      errors.add(:last_part, "must be set together with the first part")
    elsif last_part < first_part
      errors.add(:last_part, "must be greater than or equal to the first part")
    end
  end
end
