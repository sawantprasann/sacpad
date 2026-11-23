class Outreach::SendCampaignJob < ApplicationJob
  def perform(campaign_id)
    campaign = ActsAsTenant.without_tenant { Outreach::Campaign.find(campaign_id) }
    ActsAsTenant.with_tenant(campaign.organization) do
      Outreach::SendCampaign.call(campaign: campaign)
    end
  end
end
