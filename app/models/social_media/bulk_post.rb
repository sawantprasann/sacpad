module SocialMedia
  # One composed post, fanned out to many connected pages.
  # Video, prepared video, and images live in Active Storage.
  class BulkPost < ApplicationRecord
    self.table_name = "bulk_posts"

    include OrganizationScoped
    include SoftDeletable

    belongs_to :owner, class_name: "User"
    belongs_to :discarded_by, class_name: "User", optional: true
    has_many :targets, class_name: "SocialMedia::BulkPostTarget", dependent: :restrict_with_error
    has_many :social_pages, through: :targets

    has_one_attached :video
    has_one_attached :prepared_video
    has_many_attached :images

    enum :status, {
      draft: 0, queued: 1, completed: 2, partially_failed: 3, failed: 4
    }, default: :draft, prefix: :publish, validate: true
    enum :target_scope, { explicit: 0, all_connected: 1, geography: 2 }, default: :explicit, prefix: :targets, validate: true

    validate :body_or_media_present

    def publishable_video
      return prepared_video if prepared_video.attached?
      video if video.attached?
    end

    private

    def body_or_media_present
      return if body.present? || video.attached? || images.attached?

      errors.add(:base, "Add some text, a photo, or a video")
    end
  end
end
