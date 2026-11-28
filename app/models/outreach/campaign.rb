module Outreach
  # One bulk message, usually SMS, and the numbers it was sent to.
  class Campaign < ApplicationRecord
    self.table_name = "outreach_campaigns"

    include OrganizationScoped

    belongs_to :owner, class_name: "User"
    has_many :recipients, class_name: "Outreach::Recipient", foreign_key: :outreach_campaign_id, dependent: :destroy
    has_one_attached :source_file

    enum :channel, { sms: 0, whatsapp: 1 }, default: :sms, validate: true
    enum :status, { prepared: 0, sending: 1, completed: 2, failed: 3 }, default: :prepared, validate: true

    validates :body, :webhook_token, presence: true

    before_validation :assign_webhook_token, on: :create

    def refresh_counts!
      grouped = recipients.group(:status).count
      count_for = lambda do |name|
        value = Recipient.statuses[name]
        grouped[name].to_i + grouped[value].to_i + grouped[value.to_s].to_i
      end
      sent = count_for.call("sent")
      delivered = count_for.call("delivered")
      failed = count_for.call("failed")
      pending = count_for.call("pending")
      update!(
        total_count: sent + delivered + failed + pending,
        sent_count: sent + delivered,
        delivered_count: delivered,
        failed_count: failed
      )
    end

    private

    def assign_webhook_token
      self.webhook_token ||= SecureRandom.hex(24)
    end
  end
end
