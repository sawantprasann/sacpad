class PrRecord < ApplicationRecord
  # Org-scoped PR (Traditional Media) record (Story 4.2). Like Kitchen Cabinet tickets,
  # each PR record is fully tenant-isolated. Base record for all 6 categories;
  # category-specific details (Story 4.3) will extend this via separate models.
  include OrganizationScoped  # acts_as_tenant(:organization) + organization_id presence
  include SoftDeletable       # discard; discarded_at / discarded_by_id

  belongs_to :owner, class_name: "User"
  belongs_to :pr_category
  belongs_to :media_platform, optional: true  # FK if using catalog; nil if free-text fallback
  has_many_attached :attachments

  enum :sentiment, { neutral: 0, positive: 1, negative: 2 }, default: :neutral

  validates :title, presence: true
  validates :pr_category_id, presence: true
  validates :published_on, presence: true
  # media_platform_name must be present if media_platform_id is nil (free-text fallback)
  validate :media_platform_required

  before_create :assign_record_number

  private

  def media_platform_required
    if media_platform_id.blank? && media_platform_name.blank?
      errors.add(:media_platform_name, "is required if no platform is selected")
    end
  end

  # Human-readable per-org reference: PR-{org_id}-{5-digit-sequence}
  # unscoped avoids acts_as_tenant filter during create; unique index guards against race.
  def assign_record_number
    return if record_number.present?

    seq = self.class.unscoped.where(organization_id: organization_id).count + 1
    self.record_number = format("PR-%d-%05d", organization_id, seq)
  end
end
