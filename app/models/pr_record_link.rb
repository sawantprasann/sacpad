class PrRecordLink < ApplicationRecord
  belongs_to :pr_record

  validates :url, presence: true
end
