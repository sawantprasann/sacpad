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
    validates :mobile, format: { with: /\A\d{10}\z/, message: "must be a 10-digit number" }, allow_blank: true
    # Voter-ID gate (Story 1.6, FR21): a voter_id can only be attached once the ticket is closed,
    # so a voter_id on file always means help was actually delivered. Model-level invariant, not UI.
    # The one exception is an exact name match at create time, which links the voter id early.
    validate :voter_id_locked_until_closed

    attr_accessor :linking_matched_voter

    before_validation :normalize_mobile
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

    # Loose lookup to the org's Voter roll (Story 1.6, AC 3) — NOT an enforced FK. Voter#voter_id is
    # deterministically encrypted (Story 0.15), so find_by works; a non-matching id is allowed.
    def matched_voter
      return nil if voter_id.blank?

      Voter.find_by(voter_id: voter_id)
    end

    # Used only after an exact village + full-name match. Sets the voter id while the ticket
    # is still open and records transit sentiment. Close still asks for the final sentiment.
    def link_matched_voter!(voter, by:)
      self.linking_matched_voter = true
      update!(voter_id: voter.voter_id)
      VoterSentiment.find_or_create_by!(voter: voter).record_sentiment!("transit", by: by)
    end

    private

    # A new voter id is rejected until close, except the early name-match link.
    # An id already stored must survive later saves, including the move to In progress.
    def voter_id_locked_until_closed
      return if linking_matched_voter
      return unless will_save_change_to_voter_id?
      return if closed?

      errors.add(:voter_id, "unlocks once this issue is closed") if voter_id.present?
    end

    def set_defaults
      self.reported_at ||= Date.current
    end

    def normalize_mobile
      return if mobile.nil?

      digits = mobile.to_s.gsub(/\D/, "")
      self.mobile = digits.presence
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
