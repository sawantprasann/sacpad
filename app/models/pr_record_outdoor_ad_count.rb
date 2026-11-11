class PrRecordOutdoorAdCount < ApplicationRecord
  belongs_to :pr_record_entry, inverse_of: :outdoor_ad_counts
  belongs_to :outdoor_ad_type

  validates :count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :outdoor_ad_type_id, uniqueness: { scope: :pr_record_entry_id }
end
