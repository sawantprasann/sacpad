class MediaPlatform < ApplicationRecord
  # Global PR reference data (Story 4.1) — extensible list of media platforms for PR record capture.
  # Admin-managed, not org-scoped.

  before_validation :derive_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # Active platforms for PR record capture (used in dropdowns).
  scope :active, -> { where(active: true).order(:name) }

  private

  def derive_slug
    self.slug = name.parameterize
  end
end
