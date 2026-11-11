# Read at boot by the OmniAuth initializer and later by MetaApi.
# Test runs without a real Meta app, so the id and secret fall back there only.
module MetaCredentials
  module_function

  def app_id
    from_credentials(:app_id) || test_fallback("test-app-id")
  end

  def app_secret
    from_credentials(:app_secret) || test_fallback("test-app-secret")
  end

  # True only when both values were put in credentials. The test fallback does not count.
  def configured?
    from_credentials(:app_id).present? && from_credentials(:app_secret).present?
  end

  def from_credentials(key)
    Rails.application.credentials.dig(:meta, key).presence
  end

  def test_fallback(value)
    value if Rails.env.test?
  end
end
