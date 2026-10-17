class AdminContactRole < ApplicationRecord
  # Global catalog of administrative contact roles (Sarpanch, Gram Sevak, and so on).
  # Admin-managed. Not organization-scoped.
  DEFAULTS = [ "Sarpanch", "Upasarpanch", "Gram Sevak", "Police Patil", "Talathi" ].freeze

  has_many :local_admin_contacts, class_name: "GroundReports::VillageLocalAdminContact", dependent: :restrict_with_error

  before_validation :derive_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :active, -> { where(active: true).order(:name) }

  def self.seed_defaults!
    DEFAULTS.each do |name|
      find_or_create_by!(slug: name.parameterize) do |role|
        role.name = name
        role.active = true
      end
    end
  end

  private

  def derive_slug
    self.slug = name.parameterize
  end
end
