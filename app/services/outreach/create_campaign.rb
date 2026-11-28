module Outreach
  class CreateCampaign
    class Empty < StandardError; end
    class NeedText < StandardError; end

    def self.call(user:, body:, file:)
      text = body.to_s.strip
      raise NeedText if text.blank?

      phones, skipped = PhoneList.from_upload(file)
      raise Empty if phones.empty?

      campaign = Campaign.create!(owner: user, body: text, channel: :sms, status: :prepared)
      campaign.source_file.attach(file) if file.present?
      now = Time.current
      Recipient.insert_all(phones.map { |phone|
        {
          outreach_campaign_id: campaign.id,
          organization_id: campaign.organization_id,
          phone: phone,
          status: Recipient.statuses[:pending],
          created_at: now,
          updated_at: now
        }
      })
      campaign.refresh_counts!
      [ campaign, skipped ]
    end
  end
end
