module SocialMedia
  # A point-in-time read of one published target.
  # A nil count means the platform did not provide it. Zero is a real zero.
  class PostMetric < ApplicationRecord
    self.table_name = "social_post_metrics"

    include OrganizationScoped

    belongs_to :bulk_post_target, class_name: "SocialMedia::BulkPostTarget"

    validates :fetched_at, presence: true

    scope :latest_per_target, -> {
      where(id: select("DISTINCT ON (bulk_post_target_id) id").order(:bulk_post_target_id, fetched_at: :desc))
    }
  end
end
