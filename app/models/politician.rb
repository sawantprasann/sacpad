class Politician < ApplicationRecord
  # Org-scoped opponent/own-candidate roster (§6.3a), Admin-managed from the Console.
  include OrganizationScoped
  include SoftDeletable

  belongs_to :party, optional: true
  has_one_attached :photo

  validates :name, presence: true
  validate :only_one_own_politician, if: :is_own_politician?
  before_validation :default_name_to_org, if: -> { is_own_politician? && name.blank? }

  private

  def only_one_own_politician
    clash = Politician.where(is_own_politician: true).where.not(id: id)
    errors.add(:is_own_politician, "is already set for this organization") if clash.exists?
  end

  def default_name_to_org
    self.name = organization&.name
  end
end
