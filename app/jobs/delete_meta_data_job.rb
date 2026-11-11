class DeleteMetaDataJob < ApplicationJob
  queue_as :default

  def perform(provider_uid, code)
    ActsAsTenant.without_tenant do
      pages = SocialMedia::SocialPage.where(provider: [ :facebook, :instagram ], provider_uid: provider_uid)
      target_ids = SocialMedia::BulkPostTarget.where(social_page_id: pages.select(:id)).select(:id)
      SocialMedia::PostMetric.where(bulk_post_target_id: target_ids).delete_all
      pages.find_each(&:erase_meta_data!)
      SocialMedia::PendingConnection.where(provider: :facebook, provider_uid: provider_uid).delete_all
    end
    SocialMedia::MetaDeletionRequest.find_by(confirmation_code: code)&.update!(status: :completed)
  end
end
