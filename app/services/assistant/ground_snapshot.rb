module Assistant
  class GroundSnapshot
    def self.tool_name = "ground_snapshot"
    def self.available_to?(user) = user.role.can_access?("ground_reports")

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Ground Reports menu for one village: issues, worship places, political position, karyakartas, administrative contacts, and the mock poll.",
          parameters: CountBeneficiaries.place_parameters
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("place_name", "place_kind")
    end

    def self.call(user:, place:, arguments: nil, client: nil)
      village = place.is_a?(Booth) ? place.village : place
      raise VillageOnly unless village.is_a?(Village)

      label = village.display_name
      reports = Pundit.policy_scope(user, GroundReports::GroundReport).where(village: village).order(reported_at: :desc)
      worship = GroundReports::WorshipPlace.where(village: village).order(:name).limit(10).pluck(:name)
      positions = GroundReports::VillagePoliticalPosition.current.where(village: village).includes(:party).limit(5)
      karyakartas = GroundReports::VillageLocalKaryakarta.where(village: village).order(:name)
      contacts = GroundReports::VillageLocalAdminContact.where(village: village).order(:name)
      tally = GroundReports::MockPollResponse.tally_for(village)
      winners = GroundReports::MockPollResponse.likely_winners(tally)

      lines = [ I18n.t("assistant.answers.ground.issues", place: label, count: reports.count) ]
      reports.limit(5).each { |report| lines << report.issue_text.to_s.squish.truncate(160) }
      lines << I18n.t("assistant.answers.ground.worship", names: worship.presence&.join(", ") || I18n.t("assistant.none"))
      if positions.any?
        positions.each do |position|
          lines << I18n.t("assistant.answers.ground.position", name: position.representative_name, title: position.position_title, party: position.party&.name)
        end
      else
        lines << I18n.t("assistant.answers.ground.no_position")
      end
      lines << I18n.t("assistant.answers.ground.karyakartas", count: karyakartas.count, names: people(karyakartas).presence || I18n.t("assistant.none"))
      lines << I18n.t("assistant.answers.ground.contacts", names: contact_names(contacts).presence || I18n.t("assistant.none"))
      lines << I18n.t("assistant.answers.ground.poll", names: winners.map(&:name).presence&.to_sentence || I18n.t("assistant.none"))
      Answers.report(
        lines,
        link_path: Rails.application.routes.url_helpers.ground_reports_village_path(village),
        link_label: I18n.t("assistant.open_village")
      )
    end

    def self.people(rows)
      rows.limit(10).map { |person| Answers.person_label(name: person.name, phone: person.phone) }.join(", ")
    end

    def self.contact_names(rows)
      rows.limit(10).map { |contact| "#{contact.name} (#{contact.role_title}#{contact.phone.present? ? ", #{contact.phone}" : ""})" }.join("; ")
    end
  end
end
