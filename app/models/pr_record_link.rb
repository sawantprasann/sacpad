class PrRecordLink < ApplicationRecord
  belongs_to :pr_record_entry, inverse_of: :links

  validates :url, presence: true
end
