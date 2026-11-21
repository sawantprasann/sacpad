module Assistant
  class CountBeneficiaries
    def self.tool_name = "count_beneficiaries"
    def self.available_to?(user) = user.role.can_access?("kitchen_cabinet")

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Beneficiaries menu. Tickets for one village, taluka, or booth: count, status, and names.",
          parameters: {
            type: "object",
            properties: place_parameters[:properties].merge(
              status: { type: "string", enum: %w[open in_progress closed blocked], description: "Set only when the user asks for open, in progress, closed, or blocked." }
            )
          }
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("place_name", "place_kind", "status")
    end

    def self.place_parameters
      {
        type: "object",
        properties: {
          place_name: { type: "string", description: "Village, taluka, or booth, as written." },
          place_kind: { type: "string", enum: %w[village taluka booth] }
        }
      }
    end

    def self.call(user:, place:, arguments: nil, client: nil)
      summary = summary_for(user, place, arguments.to_h["status"])
      Answers.beneficiaries(
        count: summary[:count],
        match: summary[:match],
        place: PlaceFinder.new(user).choice_label(place),
        names: summary[:names],
        status: summary[:status],
        status_counts: summary[:status_counts],
        link_path: (Rails.application.routes.url_helpers.kitchen_cabinet_tickets_path(village: place.name) if place.is_a?(Village))
      )
    end

    def self.summary_for(user, place, status = nil)
      relation, match = relation_for(user, place)
      status = status.to_s
      status = nil unless KitchenCabinet::Ticket.statuses.key?(status)
      relation = relation.where(status: status) if status
      counts = relation.group(:status).count
      {
        count: counts.values.sum,
        match: match,
        status: status,
        status_counts: KitchenCabinet::Ticket.statuses.keys.index_with { |key| counts[key] || counts[KitchenCabinet::Ticket.statuses[key]] || 0 },
        names: relation.order(reported_at: :desc).limit(10).pluck(:person_name)
      }
    end

    def self.relation_for(user, place)
      tickets = Pundit.policy_scope(user, KitchenCabinet::Ticket)
      case place
      when Village
        [ count_by_village_text(tickets, folded_names([ place ])), "village_text" ]
      when Taluka
        names = folded_names(user.visible_villages(user.organization.villages).where(taluka_id: place.id))
        [ count_by_village_text(tickets, names), "village_text" ]
      when Booth
        voter_ids = Voter.where(booth_id: place.id).pluck(:voter_id)
        relation = voter_ids.empty? ? tickets.none : tickets.where(voter_id: voter_ids)
        [ relation, "voter_booth" ]
      else
        raise VillageOnly
      end
    end

    def self.folded_names(villages)
      villages.flat_map { |village| [ village.name, village.native_name ] }.compact_blank.map { |name| name.downcase }.uniq
    end

    def self.count_by_village_text(tickets, names)
      return tickets.none if names.empty?

      tickets.where("LOWER(tickets.village) IN (?)", names)
    end
  end
end
