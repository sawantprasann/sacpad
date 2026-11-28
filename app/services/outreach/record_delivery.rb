module Outreach
  # A delivery report from the SMS gateway. Status 1, or the word delivered, means the phone received it.
  class RecordDelivery
    def self.call(campaign:, number:, status:)
      phone = PhoneList.normalize(number)
      recipient = phone && campaign.recipients.find_by(phone: phone)
      return if recipient.nil?

      case status.to_s.strip.downcase
      when "1", "delivered", "received"
        recipient.update!(status: :delivered, delivered_at: Time.current, error_message: nil)
      when "2", "failed", "rejected", "undelivered"
        recipient.update!(status: :failed, error_message: status.to_s.truncate(200))
      end
      campaign.refresh_counts!
      recipient
    end
  end
end
