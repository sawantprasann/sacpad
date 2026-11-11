module SocialMedia
  # Encrypted Page list held between the OAuth callback and the checklist screen.
  # Expired rows are deleted by a housekeeping job.
  class PendingConnection < ApplicationRecord
    self.table_name = "social_pending_connections"

    include OrganizationScoped

    belongs_to :user

    encrypts :payload

    enum :provider, { facebook: 0, instagram: 1, youtube: 2, twitter: 3 }, validate: true

    before_validation { self.expires_at ||= 30.minutes.from_now }

    scope :expired, -> { where(expires_at: ...Time.current) }
    scope :fresh, -> { where(expires_at: Time.current..) }

    def items
      JSON.parse(payload)
    end

    def items=(list)
      self.payload = list.to_json
    end
  end
end
