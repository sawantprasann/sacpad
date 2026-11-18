# Read at boot by the OmniAuth initializer.
# Test runs without a real X app, so the id and secret fall back there only.
# Callback to register on the X app: /auth/twitter/callback
module TwitterCredentials
  module_function

  def client_id
    from_credentials(:client_id) || test_fallback("test-twitter-client")
  end

  def client_secret
    from_credentials(:client_secret) || test_fallback("test-twitter-secret")
  end

  # True only when both values were put in credentials. The test fallback does not count.
  def configured?
    from_credentials(:client_id).present? && from_credentials(:client_secret).present?
  end

  def from_credentials(key)
    Rails.application.credentials.dig(:twitter, key).presence
  end

  def test_fallback(value)
    value if Rails.env.test?
  end
end
