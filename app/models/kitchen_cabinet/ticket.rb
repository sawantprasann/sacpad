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
    has_many :status_changes, class_name: "KitchenCabinet::TicketStatusChange", dependent: :destroy
    has_many :follow_ups, class_name: "KitchenCabinet::TicketFollowUp", dependent: :destroy

    enum :status, { open: 0, in_progress: 1, closed: 2, blocked: 3 }, default: :open

    # Allowed status workflow (Story 1.4, FR20). closed is terminal here; the 2-step closure flow
    # (voter + sentiment) is Story 1.7. blocked → in_progress lets a blocked ticket resume.
    TRANSITIONS = {
      "open"        => %w[in_progress],
      "in_progress" => %w[closed blocked],
      "blocked"     => %w[in_progress],
      "closed"      => []
    }.freeze

    validates :person_name, presence: true

    after_initialize :set_defaults, if: :new_record?
    before_create :assign_ticket_number

    def may_change_to?(to)
      TRANSITIONS.fetch(status, []).include?(to.to_s)
    end

    # Atomically move the ticket and append its Tier-2 log row — a transition is never recorded
    # without its log row, nor vice-versa (FR53: one row per change).
    def change_status!(to:, actor:)
      raise ArgumentError, "illegal transition #{status} -> #{to}" unless may_change_to?(to)

      transaction do
        from = status
        self.status = to
        self.closed_at = Time.current if to.to_s == "closed"
        save!
        status_changes.create!(from_status: from, to_status: to.to_s, actor: actor)
      end
      true
    end

    # Time-to-resolution, derivable once closed (AC 3): closed timestamp minus the reported date.
    def resolution_duration
      return nil unless closed? && closed_at

      closed_at - reported_at.to_time
    end

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
