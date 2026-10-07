class PrCategory < ApplicationRecord
  # Global PR reference data (Story 4.1) — one shared catalog across every organization,
  # Admin-managed. Same family as TicketCategory/Party/Role: NOT OrganizationScoped, never acts_as_tenant.

  # The 6 seeded PR categories (Epic 4 brief). These are fixed and drive the PR sidebar.
  DEFAULTS = [
    { slug: "electronic",        name: "Electronic Media" },
    { slug: "print",             name: "Print Media" },
    { slug: "local-print",       name: "Local Print" },
    { slug: "local-electronic",  name: "Local Electronic" },
    { slug: "outdoor-media",     name: "Outdoor Media" },
    { slug: "podcasts",          name: "Podcasts/Interviews" }
  ].freeze

  before_validation :derive_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :display_order, presence: true
  validates :slug, presence: true, uniqueness: true

  # Active categories in sidebar/display order — drives the PR sidebar filter.
  scope :active, -> { where(active: true).order(:display_order) }

  # Seeds the 6 default PR categories idempotently (safe to re-run in every env).
  def self.seed_defaults!
    DEFAULTS.each_with_index do |attrs, i|
      find_or_create_by!(slug: attrs[:slug]) do |c|
        c.name = attrs[:name]
        c.display_order = i + 1
        c.active = true
      end
    end
  end

  private

  def derive_slug
    self.slug = name.parameterize
  end
end
