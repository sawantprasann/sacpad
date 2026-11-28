module Outreach
  class CampaignsController < ApplicationController
    skip_forgery_protection only: :deliver
    rate_limit to: 120, within: 1.minute, only: :deliver

    before_action :authenticate_user!, except: :deliver
    before_action :require_social_access, except: :deliver

    def index
      @campaigns = policy_scope(Outreach::Campaign).includes(:owner)
    end

    def new
      authorize Outreach::Campaign, :create?
      @campaign = Outreach::Campaign.new
      @sms_ready = Outreach::SmsGateway.configured?
    end

    def sample
      authorize Outreach::Campaign, :index?
      send_data Outreach::PhoneList.sample_csv,
        filename: "sms-numbers.csv",
        type: "text/csv",
        disposition: "attachment"
    end

    def show
      @campaign = policy_scope(Outreach::Campaign).find(params[:id])
      authorize @campaign
      @pagy, @recipients = pagy(:offset, @campaign.recipients.order(:id), limit: 50)
      @sms_ready = Outreach::SmsGateway.configured?
    end

    def create
      authorize Outreach::Campaign, :create?
      campaign, skipped = Outreach::CreateCampaign.call(
        user: current_user,
        body: params.dig(:campaign, :body),
        file: params.dig(:campaign, :source_file)
      )
      if Outreach::SmsGateway.configured?
        Outreach::SendCampaignJob.perform_later(campaign.id)
        notice = t("outreach.queued", count: campaign.total_count)
      else
        notice = t("outreach.saved", count: campaign.total_count)
      end
      notice = "#{notice} #{t("outreach.skipped", count: skipped)}" if skipped.positive?
      redirect_to outreach_campaign_path(campaign), notice: notice
    rescue Outreach::CreateCampaign::NeedText
      redirect_to new_outreach_campaign_path, alert: t("outreach.need_text")
    rescue Outreach::CreateCampaign::Empty
      redirect_to new_outreach_campaign_path, alert: t("outreach.no_numbers")
    end

    def send_messages
      campaign = policy_scope(Outreach::Campaign).find(params[:id])
      authorize campaign
      if Outreach::SmsGateway.configured?
        campaign.update!(status: :sending)
        Outreach::SendCampaignJob.perform_later(campaign.id)
        redirect_to outreach_campaign_path(campaign), notice: t("outreach.queued", count: campaign.recipients.pending.count)
      else
        redirect_to outreach_campaign_path(campaign), alert: t("outreach.not_configured")
      end
    end

    def deliver
      campaign = ActsAsTenant.without_tenant { Outreach::Campaign.find_by(webhook_token: params[:token].to_s) }
      return head :not_found if campaign.nil?

      ActsAsTenant.with_tenant(campaign.organization) do
        Outreach::RecordDelivery.call(
          campaign: campaign,
          number: params[:number].presence || params[:mobile],
          status: params[:status].presence || params[:desc]
        )
      end
      head :ok
    end

    private

    def require_social_access
      authorize Outreach::Campaign, :index?
    end
  end
end
