module Outreach
  class SendCampaign
    def self.call(campaign:)
      phones = campaign.recipients.pending.pluck(:phone)
      request_id = SmsGateway.deliver(message: campaign.body, phones: phones)
      now = Time.current
      campaign.recipients.pending.update_all(
        status: Recipient.statuses[:sent],
        sent_at: now,
        provider_message_id: request_id.to_s.truncate(255),
        updated_at: now
      )
      campaign.refresh_counts!
      campaign.update!(status: :completed, last_error: nil)
      campaign
    rescue SmsGateway::Error => e
      campaign.update!(status: :failed, last_error: e.message.to_s.truncate(300))
      campaign
    end
  end
end
