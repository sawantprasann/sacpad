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

    private

    def set_idempotency_key
      self.idempotency_key ||= SecureRandom.uuid
    end
  end
end
