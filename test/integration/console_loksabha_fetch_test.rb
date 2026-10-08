require "test_helper"

class ConsoleLoksabhaFetchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123", tier: :full)
    @state = State.create!(name: "Karnataka", cd: "S10")
    @district = District.create!(name: "Belagavi", state: @state, cd: "S1001")
    @loksabha = Loksabha.create!(name: "Belagavi", state: @state, district: @district, constituency_no: "2")
  end

  test "the lok sabha list has a fetch button on each row" do
    sign_in @admin
    get "/console/loksabhas"
    assert_response :success
    assert_select "button", text: "Fetch data"
  end

  test "fetch data explains when the district code is missing" do
    sign_in @admin
    @district.update!(cd: nil)

    post fetch_roll_console_loksabha_path(@loksabha)

    assert_redirected_to "/console/loksabhas"
    follow_redirect!
    assert_match "district", response.body
    assert_equal 0, Assembly.count
  end
end
