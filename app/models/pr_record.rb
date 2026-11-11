class PrRecord < ApplicationRecord
  # Org-scoped PR headline. Category, outlet, and coverage details live on entries,
  # so one headline can be logged in more than one category.
  include OrganizationScoped  # acts_as_tenant(:organization) + organization_id presence
  include SoftDeletable       # discard; discarded_at / discarded_by_id

  belongs_to :owner, class_name: "User"
  has_many :entries, -> { order(:id) }, class_name: "PrRecordEntry", dependent: :destroy, inverse_of: :pr_record

  accepts_nested_attributes_for :entries, allow_destroy: true, reject_if: :blank_entry?

  validates :title, presence: true
  validate :requires_entry

  before_create :assign_record_number

  def category_names
    entries.filter_map { |entry| entry.pr_category&.name }.uniq
  end

  def platform_names
    entries.filter_map(&:platform_name).uniq
  end

  def latest_published_on
    entries.filter_map(&:published_on).max
  end

  private

  def blank_entry?(attrs)
    return false if attrs["id"].present? || attrs[:id].present?

    category = attrs[:pr_category_id].presence || attrs["pr_category_id"].presence ||
               attrs[:pr_category].presence || attrs["pr_category"].presence
    category.blank?
  end

  def requires_entry
    return if entries.reject(&:marked_for_destruction?).any?

    errors.add(:base, I18n.t("pr.entry_required"))
  end

  # Human-readable per-org reference: PR-{org_id}-{5-digit-sequence}
  # unscoped avoids acts_as_tenant filter during create; unique index guards against race.
  def assign_record_number
    return if record_number.present?

    seq = self.class.unscoped.where(organization_id: organization_id).count + 1
    self.record_number = format("PR-%d-%05d", organization_id, seq)
  end
end
