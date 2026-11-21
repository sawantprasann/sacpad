module Assistant
  class BoothStatus
    def self.tool_name = "booth_status"
    def self.available_to?(user) = user.role.can_access?("booth_management")

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Booth Management menu for one booth or every booth in a village: voters, how many have voted, managers, and checklist.",
          parameters: CountBeneficiaries.place_parameters
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("place_name", "place_kind")
    end

    def self.call(user:, place:, arguments: nil, client: nil)
      booths = case place
      when Booth then Booth.where(id: place.id)
      when Village then Booth.where(village_id: place.id).by_number
      else raise VillageOnly
      end
      rows = booths.limit(15).to_a
      election = Election.find_by(organization: user.organization, current: true)
      lines = [ I18n.t("assistant.answers.booth.total", count: booths.count, place: PlaceFinder.new(user).choice_label(place)) ]
      rows.each do |booth|
        voters = booth.voters.count
        voted = election ? booth.voters.where(id: VoterTurnout.where(election: election, voted: true).select(:voter_id)).count : 0
        checklist = BoothChecklistItem.where(booth_id: booth.id)
        managers = User.joins(:role).where(organization_id: user.organization_id, booth_id: booth.id, roles: { slug: "booth_manager" }).order(:name).pluck(:name)
        lines << I18n.t(
          "assistant.answers.booth.row",
          booth: booth.number,
          name: booth.name.presence || booth.village.display_name,
          voters: voters,
          voted: voted,
          done: checklist.where(done: true).count,
          items: checklist.count,
          managers: managers.presence&.join(", ") || I18n.t("assistant.none")
        )
      end
      lines << I18n.t("assistant.answers.booth.more") if booths.count > rows.size
      path = place.is_a?(Booth) ? Rails.application.routes.url_helpers.booth_path(place) : Rails.application.routes.url_helpers.booths_path(village_id: place.id)
      Answers.report(lines, link_path: path, link_label: I18n.t("assistant.open_list"))
    end
  end
end
