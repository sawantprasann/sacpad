module KitchenCabinet
  # Kitchen Cabinet grievance (Story 1.2, brief §6.1). First org-scoped DOMAIN model — unlike the
  # global TicketCategory catalog, each Ticket is fully tenant-isolated. Namespaced per architecture
  # (TicketFollowUp/TicketStatusChange will join it); table name pinned to the brief's `tickets`.
  class Ticket < ApplicationRecord
    self.table_name = "tickets"

    include OrganizationScoped  # acts_as_tenant(:organization) + organization_id presence
    include SoftDeletable       # discard; discarded_at / discarded_by_id

    belongs_to :owner, class_name: "User"
    belongs_to :ticket_category, class_name: "TicketCategory"
    has_many_attached :attachments

    # Transitions (open → in_progress → closed/blocked) are Story 1.4; here status just defaults open.
    enum :status, { open: 0, in_progress: 1, closed: 2, blocked: 3 }, default: :open

    validates :person_name, presence: true

    after_initialize :set_defaults, if: :new_record?
    before_create :assign_ticket_number

    private

    def set_defaults
      self.reported_at ||= Date.current
    end

    # Human-readable per-org reference. unscoped avoids the acts_as_tenant filter during create;
    # the unique [organization_id, ticket_number] index guards against any race.
    def assign_ticket_number
      return if ticket_number.present?

      seq = self.class.unscoped.where(organization_id: organization_id).count + 1
      self.ticket_number = format("KC-%d-%05d", organization_id, seq)
    end
  end
end
