module Assistant
  class TalukaOverview
    def self.tool_name = "taluka_overview"
    def self.place_mode = :optional
    def self.available_to?(user) = user.role.can_access?("voter_lists")

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Taluka menu. Talukas in this constituency, the villages in a taluka, and how many voters each has.",
          parameters: CountBeneficiaries.place_parameters
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("place_name", "place_kind")
    end

    def self.call(user:, place: nil, arguments: nil, client: nil)
      place = place.village if place.is_a?(Booth)
      villages = user.visible_villages(user.organization.villages)
      case place
      when Taluka
        rows = villages.where(taluka_id: place.id).order(:name).limit(20)
        lines = [ I18n.t("assistant.answers.taluka.villages", place: place.display_name, count: villages.where(taluka_id: place.id).count) ]
        rows.each { |village| lines << "#{village.display_name}: #{voter_count(user, village.id)}" }
        path = Rails.application.routes.url_helpers.voter_lists_taluka_path(place)
      when Village
        lines = [ I18n.t("assistant.answers.taluka.one_village", village: place.display_name, taluka: place.taluka&.display_name || I18n.t("assistant.none"), count: voter_count(user, place.id)) ]
        path = Rails.application.routes.url_helpers.voter_lists_talukas_path
      else
        taluka_scope = Taluka.where(id: villages.where.not(taluka_id: nil).select(:taluka_id))
        lines = [ I18n.t("assistant.answers.taluka.total", count: taluka_scope.count) ]
        taluka_scope.order(:name).limit(20).each do |taluka|
          village_ids = villages.where(taluka_id: taluka.id).select(:id)
          lines << "#{taluka.display_name}: #{villages.where(taluka_id: taluka.id).count} #{I18n.t("assistant.answers.taluka.village_word")}, #{voter_count(user, village_ids)} #{I18n.t("assistant.answers.taluka.voter_word")}"
        end
        missing = villages.where(taluka_id: nil).count
        lines << I18n.t("assistant.answers.taluka.unassigned", count: missing) if missing.positive?
        path = Rails.application.routes.url_helpers.voter_lists_talukas_path
      end
      Answers.report(lines, link_path: path, link_label: I18n.t("assistant.open_list"))
    end

    def self.voter_count(user, village_id)
      user.visible_voters(Voter.where(village_id: village_id)).count
    end
  end
end
