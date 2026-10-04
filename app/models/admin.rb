class Admin < ApplicationRecord
  # Platform-operator account type (§3.0). A genuinely SEPARATE model from User:
  # no organization_id / parent_id / role_id, never tenant-scoped (no OrganizationScoped),
  # never reachable through a User-scoped query. Cross-org work happens explicitly in the
  # Console via ActsAsTenant.without_tenant (Story 0.11), not a bypass flag.
  #
  # Modules (brief §2): database_authenticatable, trackable, lockable (unlock_strategy: :time).
  # NO registerable (no self-service sign-up), NO recoverable (no self-service password reset —
  # a locked-out Admin is recovered out-of-band), NO rememberable.
  devise :database_authenticatable, :trackable, :lockable, :validatable

  # full = unrestricted, platform-wide. ops = scoped to assigned orgs (join table in Story 0.5/0.11).
  enum :tier, { full: 0, ops: 1 }, default: :full, validate: true

  has_many :admin_organizations, dependent: :destroy
  has_many :organizations, through: :admin_organizations

  validates :name, presence: true

  # Organizations this admin may operate on: full tier = every org; ops tier = assigned only (§3.0).
  def assignable_organizations
    full? ? Organization.all : organizations
  end

  # Deactivated admins cannot authenticate.
  def active_for_authentication?
    super && active?
  end
end
