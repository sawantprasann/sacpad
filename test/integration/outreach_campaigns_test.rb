require "test_helper"

class OutreachCampaignsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Outreach Org #{SecureRandom.hex(4)}") }
    ActsAsTenant.with_tenant(@org) do
      @admin = user_with_role("org_admin")
      @reader = user_with_access("read")
    end
  end

  test "a csv of numbers is saved and a delivery report counts who received it" do
    gateway = Outreach::SmsGateway.singleton_class
    gateway.alias_method(:__orig_configured?, :configured?)
    gateway.alias_method(:__orig_deliver, :deliver)
    sent = nil
    Outreach::SmsGateway.define_singleton_method(:configured?) { true }
    Outreach::SmsGateway.define_singleton_method(:deliver) do |**kwargs|
      sent = kwargs[:phones]
      "req-1"
    end

    sign_in @admin
    csv = Tempfile.new([ "numbers", ".csv" ])
    csv.write("mobile\n9876543210\n91 91234 56789\nnot-a-number\n")
    csv.rewind

    assert_enqueued_with(job: Outreach::SendCampaignJob) do
      post outreach_campaigns_path, params: {
        campaign: {
          body: "Booth meeting tonight",
          source_file: Rack::Test::UploadedFile.new(csv.path, "text/csv")
        }
      }
    end
    assert_response :redirect
    perform_enqueued_jobs
    assert_equal [ "919876543210", "919123456789" ], sent

    campaign = ActsAsTenant.with_tenant(@org) { Outreach::Campaign.last }
    assert_equal 2, campaign.sent_count
    assert_equal 0, campaign.delivered_count

    post outreach_delivery_path(campaign.webhook_token), params: { number: "9876543210", status: "delivered" }
    assert_response :success
    campaign.reload
    assert_equal 1, campaign.delivered_count
    assert_equal 2, campaign.sent_count

    get outreach_campaign_path(campaign)
    assert_response :success
    assert_match I18n.t("outreach.received_count", received: 1, total: 2), response.body
    assert_no_match "page-secret-token", response.body
  ensure
    gateway&.alias_method(:configured?, :__orig_configured?) if gateway&.method_defined?(:__orig_configured?)
    gateway&.alias_method(:deliver, :__orig_deliver) if gateway&.method_defined?(:__orig_deliver)
    csv&.close!
  end

  test "numbers are kept when the sms gateway is not configured" do
    sign_in @admin
    csv = Tempfile.new([ "numbers", ".csv" ])
    csv.write("9876543210\n")
    csv.rewind
    post outreach_campaigns_path, params: {
      campaign: { body: "Hello booth", source_file: Rack::Test::UploadedFile.new(csv.path, "text/csv") }
    }
    assert_response :redirect
    campaign = ActsAsTenant.with_tenant(@org) { Outreach::Campaign.last }
    assert campaign.prepared?
    assert_equal 1, campaign.total_count
    assert_equal 0, campaign.sent_count
    follow_redirect!
    assert_match I18n.t("outreach.not_configured"), response.body

    get sample_outreach_campaigns_path
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_equal Outreach::PhoneList.sample_csv, response.body
  ensure
    csv&.close!
  end

  test "a reader cannot send a message" do
    sign_in @reader
    get outreach_campaigns_path
    assert_response :success
    assert_match I18n.t("social.channels.sms"), response.body
    assert_match I18n.t("social.channels.whatsapp"), response.body
    assert_match I18n.t("social.channels.ivrs"), response.body
    assert_select "a[href=?]", new_outreach_campaign_path, count: 0
    get new_outreach_campaign_path
    assert_response :not_found
  end

  private

  def user_with_role(slug)
    role = Role.find_or_create_by!(slug: slug) { |record| record.name = slug.titleize }
    role.role_permissions.find_or_create_by!(module_name: "social_media") { |permission| permission.access_level = "write" }
    User.create!(organization: @org, role: role, name: slug.titleize, email: "#{slug}-#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def user_with_access(level)
    role = Role.create!(name: "Outreach #{level}", slug: "outreach-#{level}-#{SecureRandom.hex(4)}")
    role.role_permissions.create!(module_name: "social_media", access_level: level)
    User.create!(organization: @org, role: role, name: "Outreach #{level}", email: "outreach-#{SecureRandom.hex(4)}@example.com", password: "password123")
  end
end
