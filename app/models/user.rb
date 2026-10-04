class User < ApplicationRecord
  # Org-facing account (§3.2). Modules (brief §2): database_authenticatable, recoverable,
  # rememberable, trackable, lockable, validatable — NO registerable (no self-service sign-up).
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :lockable, :validatable

  # Self-referential hierarchy of unlimited depth (closure_tree). Provides parent/children/
  # ancestors/descendants/self_and_descendant_ids. parent_id nil = org_admin root.
  has_closure_tree

  # User is org-scoped DATA (organization_id + Pundit + subtree) but is intentionally NOT
  # acts_as_tenant: Devise authenticates by email with no tenant context. Email is globally unique.
  belongs_to :organization
  belongs_to :role
  has_one_attached :photo

  validates :name, presence: true

  after_commit :clear_subtree_cache

  # Cached set of ids the user may see (self + all descendants) — runs on nearly every
  # authorized request, so it's the highest-leverage cache (§3.2/§8b). Solid Cache in prod;
  # NullStore in test (recomputes). Invalidated when the hierarchy under the user changes.
  def subtree_user_ids
    Rails.cache.fetch([ cache_key_with_version, "subtree_ids" ]) { [ id, *descendant_ids ] }
  end

  # Blocked if the user is inactive OR their organization is deactivated (cascade, §3.1a).
  def active_for_authentication?
    super && active? && organization&.active?
  end

  private

  # Best-effort invalidation: clear this user's and its ancestors' caches on change.
  def clear_subtree_cache
    ([ self ] + (persisted? ? ancestors.to_a : [])).each do |u|
      Rails.cache.delete([ u.cache_key_with_version, "subtree_ids" ])
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
