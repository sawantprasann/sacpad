class Role < ApplicationRecord
  # Data-defined roles (§3.3). Global in v1 (organization_id nil); Admin-defined only.
  # NOT OrganizationScoped — roles are shared reference data, not tenant data.
  MODULES = %w[
    kitchen_cabinet cadre_program ground_reports pr
    mainline_fan_page_media social_media voter_lists rag_mapping
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

  # Seeds the two v1 system roles (idempotent): org_admin (full write + can_create_users)
  # and dreamline_user (full write, no user creation). Both write-all per the v1 decision (§4/§9 #1).
  def self.seed_system_roles!
    org_admin = find_or_create_by!(slug: "org_admin") do |r|
      r.name = "Org Admin"
      r.is_system = true
      r.can_create_users = true
    end
    dreamline = find_or_create_by!(slug: "dreamline_user") do |r|
      r.name = "Dreamline User"
      r.is_system = true
      r.can_create_users = false
    end
    [ org_admin, dreamline ].each do |role|
      MODULES.each do |m|
        role.role_permissions.find_or_create_by!(module_name: m) { |p| p.access_level = "write" }
      end
    end
    [ org_admin, dreamline ]
  end
end
