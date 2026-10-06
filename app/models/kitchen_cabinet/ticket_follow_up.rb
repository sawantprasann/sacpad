module KitchenCabinet
  # Per-ticket follow-up note (Story 1.5, FR23): a running, append-only record of what was actually
  # done about the issue — timestamped, attributed, with an optional attachment. Org-scoped +
  # isolation-tested like every tenant model. Distinct from the Tier-2 status-change log.
  class TicketFollowUp < ApplicationRecord
    self.table_name = "ticket_follow_ups"

    include OrganizationScoped

    belongs_to :ticket, class_name: "KitchenCabinet::Ticket"
    belongs_to :created_by, class_name: "User"
    has_one_attached :attachment

    validates :note, presence: true
  end
end
