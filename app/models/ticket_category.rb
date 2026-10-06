class TicketCategory < ApplicationRecord
  # Global Kitchen Cabinet reference data (Story 1.1, brief §6.1) — one shared catalog across
  # every organization, Admin-managed. Same family as Party/Role/State: NOT OrganizationScoped,
  # never acts_as_tenant. The Ticket records filed under each category (Story 1.2) are org-scoped;
  # the category list is not.
  #
  # Kept top-level (not KitchenCabinet::) to match the other global reference-data models and the
  # Console::ReferenceController catalog pattern, which is built around top-level reference models.

  # The 12 seeded categories (brief §6.1), in display order. "Other" is the catch-all, always last.
  DEFAULTS = [
    { slug: "health",          name: "Health" },
    { slug: "road-transport",  name: "Road & Transport" },
    { slug: "water",           name: "Water" },
    { slug: "electricity",     name: "MSEB/Electricity (power)" },
    { slug: "student",         name: "Student" },
    { slug: "police-station",  name: "Police Station" },
    { slug: "farmers",         name: "Farmers" },
    { slug: "events-camps",    name: "Events & Camps" },
    { slug: "personal-help",   name: "Personal Help" },
    { slug: "personal-connect", name: "Personal Connect" },
    { slug: "functions",       name: "Functions – Weddings/Birthdays" },
    { slug: "other",           name: "Other" }
  ].freeze

  before_validation :derive_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :display_order, presence: true
  validates :slug, presence: true, uniqueness: true

  # Active categories in sidebar/display order — drives the Kitchen Cabinet submenu.
  scope :active, -> { where(active: true).order(:display_order) }

  # Seeds the 12 default categories idempotently (safe to re-run in every env), mirroring
  # Role.seed_system_roles!. display_order follows DEFAULTS order so "Other" lands last.
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
