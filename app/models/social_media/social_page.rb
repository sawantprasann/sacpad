module SocialMedia
  # A connected Facebook Page, Instagram professional account, YouTube channel,
  # or X account. The organization owns the connection. owner is the teammate
  # who manages the row. The karyakarta who runs the page may not be a User.
  class SocialPage < ApplicationRecord
    self.table_name = "social_pages"

    include OrganizationScoped
    include SoftDeletable

    belongs_to :owner, class_name: "User"
    belongs_to :karyakarta_user, class_name: "User", optional: true
    belongs_to :politician, optional: true
    belongs_to :discarded_by, class_name: "User", optional: true
    has_many :bulk_post_targets, class_name: "SocialMedia::BulkPostTarget", dependent: :restrict_with_error
    has_many :metric_snapshots, class_name: "SocialMedia::PageMetricSnapshot", dependent: :destroy

    encrypts :access_token, :refresh_token

    enum :provider, { facebook: 0, instagram: 1, youtube: 2, twitter: 3 }, validate: true
    enum :page_type, { karyakarta: 0, official: 1, fan: 2, opposition: 3 }, default: :karyakarta, validate: true
    enum :status, { active: 0, needs_reauth: 1, disconnected: 2 }, default: :active, prefix: :connection, validate: true

    validates :external_id, presence: true
    validates :external_id, uniqueness: { scope: [ :organization_id, :provider ], conditions: -> { kept } }

    def token_expired?
      expires_at.present? && expires_at <= 1.minute.from_now
    end

    def disconnect!
      update!(status: :disconnected, access_token: nil, refresh_token: nil)
    end

    # Meta data-deletion: drop the token and the names we stored from Facebook.
    def erase_meta_data!
      update!(
        status: :disconnected,
        access_token: nil,
        refresh_token: nil,
        name: nil,
        username: nil,
        url: nil,
        profile_image_url: nil
      )
    end
  end
end
