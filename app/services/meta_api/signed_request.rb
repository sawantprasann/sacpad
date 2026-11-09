module MetaApi
  module SignedRequest
    # Returns the decoded payload Hash, or nil when the signature does not match.
    def self.parse(signed_request)
      return nil if signed_request.blank?

      encoded_sig, payload = signed_request.split(".", 2)
      return nil if encoded_sig.blank? || payload.blank?

      secret = MetaCredentials.app_secret
      return nil if secret.blank?

      expected = OpenSSL::HMAC.digest("SHA256", secret, payload)
      sig = decode(encoded_sig)
      return nil unless sig.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(sig, expected)

      JSON.parse(decode(payload))
    rescue ArgumentError, JSON::ParserError
      nil
    end

    # Facebook omits the trailing "=" padding.
    def self.decode(value)
      Base64.urlsafe_decode64(value + ("=" * ((4 - value.length % 4) % 4)))
    end
    private_class_method :decode
  end
end
