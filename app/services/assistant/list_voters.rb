module Assistant
  class ListVoters
    STATUSES = %w[pleased transit displeased].freeze

    def self.tool_name = "list_voters"
    def self.available_to?(user) = user.role.can_access?("voter_lists")

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Voter Lists menu. Voters in one village, taluka, or booth. Set sentiment only for pleased, transit, or displeased.",
          parameters: {
            type: "object",
            properties: CountBeneficiaries.place_parameters[:properties].merge(
              sentiment: { type: "string", enum: STATUSES, description: "Leave empty for the whole roll." }
            )
          }
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("place_name", "place_kind", "sentiment")
    end

    def self.call(user:, place:, arguments: {}, client: nil)
      status = arguments.to_h["sentiment"].to_s
      status = nil unless STATUSES.include?(status)
      voters = voters_for(user, place)
      if status
        voter_ids = VoterSentiment.where(sentiment_status: status, voter_id: voters.select(:id)).select(:voter_id)
        voters = voters.where(id: voter_ids)
      end
      names = voters.limit(20).map(&:display_name)
      Answers.voters(
        count: voters.count,
        names: names,
        sentiment: status,
        place: PlaceFinder.new(user).choice_label(place),
        link_path: link_for(place, status)
      )
    end

    def self.summary_for(user, place, status)
      voters = voters_for(user, place)
      voter_ids = VoterSentiment.where(sentiment_status: status, voter_id: voters.select(:id)).select(:voter_id)
      scoped = voters.where(id: voter_ids)
      { count: scoped.count, names: scoped.limit(20).map(&:display_name) }
    end

    def self.voters_for(user, place)
      case place
      when Village then user.visible_voters(Voter.where(village_id: place.id))
      when Taluka
        ids = user.visible_villages(user.organization.villages).where(taluka_id: place.id).select(:id)
        user.visible_voters(Voter.where(village_id: ids))
      when Booth then user.visible_voters(Voter.where(booth_id: place.id))
      else raise VillageOnly
      end
    end

    def self.link_for(place, status)
      routes = Rails.application.routes.url_helpers
      case place
      when Village then routes.voters_path(village_id: place.id, sentiment: status)
      when Booth then routes.voters_path(village_id: place.village_id, booth: place.number, sentiment: status)
      end
    end
  end
end
