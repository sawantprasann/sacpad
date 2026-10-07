class PrRecordPodcast < ApplicationRecord
  belongs_to :pr_record

  validates :recording_date, presence: true
end
