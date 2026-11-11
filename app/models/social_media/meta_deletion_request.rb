module SocialMedia
  # Meta's data-deletion callback has no session and no organization.
  # Look up by confirmation_code. Do not tenant-scope this model.
  class MetaDeletionRequest < ApplicationRecord
    self.table_name = "meta_deletion_requests"

    enum :status, { pending: 0, completed: 1 }, default: :pending, prefix: true, validate: true

    validates :confirmation_code, presence: true, uniqueness: true
    validates :provider, :provider_uid, presence: true
  end
end
