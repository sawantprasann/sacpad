class PrRecordEntry < ApplicationRecord
  # One appearance of a PR headline: a category plus the outlet, date, and details for that appearance.
  belongs_to :pr_record, inverse_of: :entries
  belongs_to :pr_category
  belongs_to :media_platform, optional: true

  has_many :links, class_name: "PrRecordLink", dependent: :destroy, inverse_of: :pr_record_entry
  has_many :outdoor_ad_counts, class_name: "PrRecordOutdoorAdCount", dependent: :destroy, inverse_of: :pr_record_entry
  has_one :podcast, class_name: "PrRecordPodcast", dependent: :destroy, inverse_of: :pr_record_entry
  has_many_attached :attachments

  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: ->(attrs) { attrs[:url].blank? && attrs["url"].blank? }
  accepts_nested_attributes_for :outdoor_ad_counts, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :podcast, allow_destroy: true, reject_if: :all_blank

  before_save :sync_primary_link

  enum :sentiment, { neutral: 0, positive: 1, negative: 2 }, default: :neutral

  validates :published_on, presence: true
  validate :media_platform_required

  # Podcasts are links only. Outdoor records use ad types. The other categories pick a catalog name.
  PLATFORM_OPTIONAL_SLUGS = %w[podcasts outdoor-media].freeze

  def platform_name
    media_platform&.name.presence || media_platform_name.presence
  end

  private

  def media_platform_required
    return if PLATFORM_OPTIONAL_SLUGS.include?(pr_category&.slug)
    return if media_platform_id.present? || media_platform_name.present?

    errors.add(:media_platform_name, "is required if no platform is selected")
  end

  def sync_primary_link
    first = links.reject(&:marked_for_destruction?).find { |link| link.url.present? }
    return if first.blank?

    self.url = first.url
    self.thumbnail_url = first.thumbnail_url if first.thumbnail_url.present?
  end
end
