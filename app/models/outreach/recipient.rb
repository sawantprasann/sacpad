module Outreach
  class Recipient < ApplicationRecord
    self.table_name = "outreach_recipients"

    include OrganizationScoped

    belongs_to :campaign, class_name: "Outreach::Campaign", foreign_key: :outreach_campaign_id

    enum :status, { pending: 0, sent: 1, delivered: 2, failed: 3 }, default: :pending, validate: true

    validates :phone, presence: true, uniqueness: { scope: :outreach_campaign_id }
  end
end
