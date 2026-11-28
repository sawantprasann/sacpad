module SocialMedia
  # One destination for a bulk post. A failure here does not fail the other pages.
  class BulkPostTarget < ApplicationRecord
    self.table_name = "bulk_post_targets"

    include OrganizationScoped

    belongs_to :bulk_post, class_name: "SocialMedia::BulkPost"
    belongs_to :social_page, class_name: "SocialMedia::SocialPage"
    has_many :post_metrics, class_name: "SocialMedia::PostMetric", dependent: :destroy

    enum :status, {
      pending: 0, processing: 1, published: 2, failed: 3
    }, default: :pending, prefix: true, validate: true

    before_validation :set_idempotency_key, on: :create

    validates :idempotency_key, presence: true, uniqueness: true

    def latest_metric
      post_metrics.order(fetched_at: :desc).first
    end

    def synced_from_network?
      return false if idempotency_key.to_s.start_with?("publish:")
      return false if provider_state.to_h["source"] == "sacpad"

      idempotency_key.to_s.start_with?("facebook:") || provider_state.to_h["source"] == "facebook"
    end

    scope :synced_from_network, -> {
      where("idempotency_key LIKE 'facebook:%' OR (provider_state ->> 'source' = ? AND idempotency_key NOT LIKE 'publish:%')", "facebook")
    }

    private

    def set_idempotency_key
      self.idempotency_key ||= SecureRandom.uuid
    end
  end
end
