class Organization < ApplicationRecord
  # The tenant itself — NOT acts_as_tenant-scoped (it is the scope).
  belongs_to :constituency, polymorphic: true, optional: true  # one Loksabha OR Assembly (§3.1c)
  belongs_to :current_party, class_name: "Party", optional: true

  has_many :users, dependent: :restrict_with_error
  has_many :party_memberships, dependent: :destroy
  has_many :admin_organizations, dependent: :destroy
  has_many :politicians, dependent: :destroy
  has_many :pr_records, dependent: :destroy

  validates :name, presence: true
  validates :constituency_type, inclusion: { in: %w[Loksabha Assembly] }, allow_nil: true

  scope :active, -> { where(active: true) }

  after_update_commit :sync_own_politician_name

  # Which assemblies/villages this org operates in, derived from the constituency (§3.1c).
  def assemblies
    case constituency_type
    when "Assembly" then Assembly.where(id: constituency_id)
    when "Loksabha" then Assembly.where(loksabha_id: constituency_id)
    else Assembly.none
    end
  end

  def villages
    Village.where(assembly_id: assemblies.select(:id))
  end

  # Deactivation cascade (§3.1a): one toggle cuts off every user under the org (enforced in
  # User#active_for_authentication? and in Pundit scopes).
  def deactivate! = update!(active: false)
  def reactivate! = update!(active: true)

  private

  # Keep the own-candidate's name in sync with the organization name (§6.3a).
  def sync_own_politician_name
    return unless saved_change_to_name?

    ActsAsTenant.with_tenant(self) do
      politicians.where(is_own_politician: true).update_all(name: name, updated_at: Time.current)
    end
  end
end
