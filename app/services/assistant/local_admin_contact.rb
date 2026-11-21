module Assistant
  class LocalAdminContact
    def self.tool_name = "local_admin_contact"
    def self.available_to?(user) = user.role.can_access?("ground_reports")

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Ground Reports administrative contacts for one village, including the sarpanch. Set role to sarpanch when the user asks for the sarpanch.",
          parameters: {
            type: "object",
            properties: CountBeneficiaries.place_parameters[:properties].merge(
              role: { type: "string", description: "Contact role, such as sarpanch. Leave empty for every contact." }
            )
          }
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("place_name", "place_kind", "role")
    end

    def self.call(user:, place:, arguments: nil, client: nil)
      raise VillageOnly unless place.is_a?(Village)

      role = arguments.to_h["role"].to_s
      contacts = GroundReports::VillageLocalAdminContact.where(village: place).order(:id)
      sarpanch_only = role.match?(/sarpanch|सरपंच/i)
      contacts = contacts.select { |contact| sarpanch?(contact.role_title) } if sarpanch_only
      if !sarpanch_only && role.present?
        folded = PlaceFinder.fold(role)
        contacts = contacts.select { |contact| PlaceFinder.fold(contact.role_title).include?(folded) }
      end
      if sarpanch_only
        return Answers.sarpanch(
          contacts: contacts.map { |contact| { name: contact.name, phone: contact.phone } },
          place: place.display_name,
          link_path: Rails.application.routes.url_helpers.ground_reports_village_path(place)
        )
      end

      lines = [ I18n.t("assistant.answers.contacts.total", place: place.display_name, count: contacts.size) ]
      contacts.first(10).each do |contact|
        lines << "#{Answers.person_label(name: contact.name, phone: contact.phone)} · #{contact.role_title}"
      end
      lines << I18n.t("assistant.answers.contacts.none") if contacts.empty?
      Answers.report(lines, link_path: Rails.application.routes.url_helpers.ground_reports_village_path(place), link_label: I18n.t("assistant.open_village"))
    end

    def self.sarpanch?(title)
      text = title.to_s.squish.downcase
      text == "सरपंच" || text.match?(/\bsarpanch\b/)
    end
  end
end
