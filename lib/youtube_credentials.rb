# Read at boot by the OmniAuth initializer.
# Test runs without a real Google app, so the id and secret fall back there only.
# Callback to register on the Google client: /auth/youtube/callback
module YoutubeCredentials
  module_function

  def client_id
    from_credentials(:client_id) || test_fallback("test-youtube-client")
  end

  def client_secret
    from_credentials(:client_secret) || test_fallback("test-youtube-secret")
  end

  # True only when both values were put in credentials. The test fallback does not count.
  def configured?
    from_credentials(:client_id).present? && from_credentials(:client_secret).present?
  end

  def from_credentials(key)
    Rails.application.credentials.dig(:youtube, key).presence
  end

  def test_fallback(value)
    value if Rails.env.test?
  end
end
