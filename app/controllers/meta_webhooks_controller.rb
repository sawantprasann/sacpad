class MetaWebhooksController < ApplicationController
  skip_forgery_protection
  rate_limit to: 120, within: 1.minute

  def deauthorize
    data = MetaApi::SignedRequest.parse(params[:signed_request])
    return head :bad_request if data.blank? || data["user_id"].blank?

    uid = data["user_id"].to_s
    ActsAsTenant.without_tenant do
      SocialMedia::SocialPage.where(provider: [ :facebook, :instagram ], provider_uid: uid).find_each(&:disconnect!)
    end
    head :ok
  end

  def data_deletion
    data = MetaApi::SignedRequest.parse(params[:signed_request])
    return head :bad_request if data.blank? || data["user_id"].blank?

    code = SecureRandom.hex(10)
    SocialMedia::MetaDeletionRequest.create!(
      confirmation_code: code, provider: "meta", provider_uid: data["user_id"].to_s
    )
    DeleteMetaDataJob.perform_later(data["user_id"].to_s, code)
    render json: { url: data_deletion_status_url(code: code), confirmation_code: code }
  end
end
