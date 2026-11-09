require "test_helper"

class MetaApi::SignedRequestTest < ActiveSupport::TestCase
  test "a valid signature parses" do
    payload = Base64.urlsafe_encode64({ user_id: "123" }.to_json).delete("=")
    sig = Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", MetaCredentials.app_secret, payload)).delete("=")

    assert_equal "123", MetaApi::SignedRequest.parse("#{sig}.#{payload}")["user_id"]
  end

  test "a tampered payload is rejected" do
    assert_nil MetaApi::SignedRequest.parse("abc.def")
  end
end
