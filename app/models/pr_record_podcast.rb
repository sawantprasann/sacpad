class PrRecordPodcast < ApplicationRecord
  belongs_to :pr_record_entry, inverse_of: :podcast

  validates :recording_date, presence: true
end
