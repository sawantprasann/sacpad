class MediaPlatform < ApplicationRecord
  # Global PR reference data (Story 4.1) — extensible list of media platforms for PR record capture.
  # Admin-managed, not org-scoped.

  DEFAULTS = {
    "TV News" => { slug: "tv-news", active: true },
    "Newspaper" => { slug: "newspaper", active: true },
    "Radio" => { slug: "radio", active: true },
    "Website" => { slug: "website", active: true },
    "Social Media" => { slug: "social-media", active: true },
    "News Wire" => { slug: "news-wire", active: true },
  }.freeze

  before_validation :derive_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # Active platforms for PR record capture (used in dropdowns).
  scope :active, -> { where(active: true).order(:name) }

  def self.seed_defaults!
    DEFAULTS.each do |name, attrs|
      find_or_create_by!(slug: attrs[:slug]) do |p|
        p.name = name
        p.active = attrs[:active]
      end
    end
  end

  private

  def derive_slug
    self.slug = name.parameterize
  end
end
