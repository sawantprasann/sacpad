module Outreach
  # MSG91 SMS. Indian carriers deliver a message only when it matches a
  # DLT-approved template, so the auth key, sender id, and template id are required.
  class SmsGateway
    class Error < StandardError; end

    URL = "https://control.msg91.com/api/v5/sms/send"

    def self.configured?
      auth_key.present? && sender_id.present? && template_id.present?
    end

    def self.deliver(message:, phones:)
      raise Error, "SMS gateway is not configured" unless configured?
      raise Error, "No numbers to send" if phones.blank?

      response = Faraday.post(URL) do |request|
        request.options.timeout = 20
        request.headers["authkey"] = auth_key
        request.headers["content-type"] = "application/json"
        request.headers["accept"] = "application/json"
        request.body = {
          sender: sender_id,
          route: "4",
          country: "91",
          DLT_TE_ID: template_id,
          sms: [ { message: message, to: phones } ]
        }.to_json
      end
      body = response.body.to_s
      parsed = JSON.parse(body)
      raise Error, parsed["message"].presence || "SMS gateway returned #{response.status}" unless response.success?

      parsed["request_id"].presence || parsed["message"].to_s
    rescue JSON::ParserError
      raise Error, "SMS gateway returned an unreadable response"
    rescue Faraday::Error => e
      raise Error, e.message.to_s.truncate(200)
    end

    def self.auth_key
      ENV["MSG91_AUTH_KEY"].presence || Rails.application.credentials.dig(:msg91, :auth_key).presence
    end

    def self.sender_id
      ENV["MSG91_SENDER_ID"].presence || Rails.application.credentials.dig(:msg91, :sender_id).presence
    end

    def self.template_id
      ENV["MSG91_TEMPLATE_ID"].presence || Rails.application.credentials.dig(:msg91, :template_id).presence
    end
  end
end
