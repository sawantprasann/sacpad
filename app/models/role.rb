class Role < ApplicationRecord
  # Data-defined roles (§3.3). Global in v1 (organization_id nil); Admin-defined only.
  # NOT OrganizationScoped — roles are shared reference data, not tenant data.
  MODULES = %w[
    kitchen_cabinet cadre_program ground_reports pr
    mainline_fan_page_media social_media voter_lists booth_management
  ].freeze

  belongs_to :organization, optional: true
  has_many :role_permissions, dependent: :destroy
  has_many :users, dependent: :restrict_with_error
  accepts_nested_attributes_for :role_permissions

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # Access level for a module: "none" / "read" / "write".
  def access_for(mod)
    role_permissions.detect { |p| p.module_name == mod.to_s }&.access_level || "none"
  end

  def can_access?(mod) = access_for(mod) != "none"
  def can_write?(mod)  = access_for(mod) == "write"

  # System roles. Org Admin can create users. PA, Karyakarta, and Manager sit under
  # that admin: full module write, no user creation. Dreamline User stays the same.
  SYSTEM_ROLES = [
    { slug: "org_admin", name: "Org Admin", can_create_users: true },
    { slug: "manager", name: "Manager", can_create_users: false },
    { slug: "pa", name: "PA", can_create_users: false },
    { slug: "karyakarta", name: "Karyakarta", can_create_users: false },
    { slug: "dreamline_user", name: "Dreamline User", can_create_users: false },
    { slug: "booth_manager", name: "Booth Manager", can_create_users: false, access: { "voter_lists" => "write" } }
  ].freeze

  def self.seed_system_roles!
    SYSTEM_ROLES.map do |attrs|
      role = find_or_create_by!(slug: attrs[:slug]) do |r|
        r.name = attrs[:name]
        r.is_system = true
        r.can_create_users = attrs[:can_create_users]
      end
      access = attrs[:access] || MODULES.index_with { "write" }
      access.each do |mod, level|
        role.role_permissions.find_or_create_by!(module_name: mod) { |p| p.access_level = level }
      end
      role
    end
  end
end
