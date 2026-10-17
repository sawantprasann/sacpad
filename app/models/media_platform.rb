class MediaPlatform < ApplicationRecord
  # Global PR reference data (Story 4.1) — extensible list of media platforms for PR record capture.
  # Admin-managed, not org-scoped.

  # Each PR category has its own outlets. Electronic is TV channels. Print is mainline papers.
  # Local papers and local channels are added by an administrator; they are not seeded here.
  CATALOG = {
    "electronic" => [ "ABP Majha", "TV9 Marathi", "Zee 24 Taas", "Saam TV", "News18 Lokmat" ],
    "print" => [ "Lokmat", "Sakal", "Pudhari" ]
  }.freeze

  belongs_to :pr_category, optional: true

  before_validation :derive_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # Active platforms for PR record capture (used in dropdowns).
  scope :active, -> { where(active: true).order(:name) }
  scope :for_category, ->(category) { where(pr_category: category) }

  def self.seed_defaults!
    PrCategory.seed_defaults!
    CATALOG.each do |category_slug, names|
      category = PrCategory.find_by!(slug: category_slug)
      names.each do |name|
        platform = find_or_create_by!(slug: name.parameterize) do |row|
          row.name = name
          row.active = true
          row.pr_category = category
        end
        platform.update!(pr_category: category, active: true) if platform.pr_category_id.nil?
      end
    end
  end

  private

  def derive_slug
    self.slug = name.parameterize
  end
end
