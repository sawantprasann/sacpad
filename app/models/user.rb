class User < ApplicationRecord
  # Org-facing account (§3.2). Modules (brief §2): database_authenticatable, recoverable,
  # rememberable, trackable, lockable — NO registerable (no self-service sign-up).
  # NOTE: unlock_strategy is global :time (set in 0.3). User's :both (email unlock) is a
  # deferred refinement (needs the unlock mailer); unlock_token column exists so it's a
  # config change, not a migration, later.
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :lockable, :validatable

  # User is org-scoped DATA (organization_id + Pundit + subtree) but is intentionally NOT
  # acts_as_tenant: Devise authenticates by email with no tenant context, so the account
  # model must be queryable without a current tenant. Email is globally unique.
  belongs_to :organization
  belongs_to :role
  belongs_to :parent, class_name: "User", optional: true
  has_many :children, class_name: "User", foreign_key: :parent_id,
                      inverse_of: :parent, dependent: :restrict_with_error
  has_one_attached :photo

  validates :name, presence: true

  # Deactivated user cannot authenticate. Organization-level cascade is Story 0.6.
  def active_for_authentication?
    super && active?
  end
end
