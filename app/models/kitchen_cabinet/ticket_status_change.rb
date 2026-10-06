module KitchenCabinet
  # Tier-2 lightweight status-transition log (Story 1.4, FR53): one append-only row per ticket
  # status change — who moved it from X to Y and when. NOT Tier-1/PaperTrail. Still tenant data, so
  # org-scoped + isolation-tested like every domain model.
  class TicketStatusChange < ApplicationRecord
    self.table_name = "ticket_status_changes"

    include OrganizationScoped

    belongs_to :ticket, class_name: "KitchenCabinet::Ticket"
    belongs_to :actor, class_name: "User"

    validates :to_status, presence: true
  end
end
