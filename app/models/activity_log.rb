class ActivityLog < ApplicationRecord
  # Append-only; never updated or deleted. Not tenant-scoped (records cross-org admin access).
  belongs_to :actor, polymorphic: true
  belongs_to :record, polymorphic: true, optional: true

  def self.record!(actor:, action:, record: nil, organization: nil)
    create!(
      actor: actor,
      action: action,
      record: record,
      organization_id: organization&.id || record.try(:organization_id),
      created_at: Time.current
    )
  end
end
