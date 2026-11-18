require "test_helper"

class PrivacyTest < ActionDispatch::IntegrationTest
  test "the privacy policy is public and stays in english" do
    get privacy_path, headers: { "Cookie" => "locale=mr" }

    assert_response :success
    assert_match "Privacy policy", response.body
    assert_match "Limited Use requirements", response.body
    assert_match "https://developers.google.com/terms/api-services-user-data-policy", response.body
    assert_match "https://www.youtube.com/t/terms", response.body
    assert_match "https://policies.google.com/privacy", response.body
    assert_match "mailto:support@politomatrix.com", response.body
    assert_no_match "sawantprasann155@gmail.com", response.body
    assert_no_match "गोपनीयता", response.body
    assert_no_match "मराठी", response.body
    assert_select "a[href=?]", new_user_session_path, text: "Back to sign in"

    get new_user_session_path
    assert_response :success
    assert_select "footer a[href=?]", privacy_path, text: "Privacy policy"
  end
end
