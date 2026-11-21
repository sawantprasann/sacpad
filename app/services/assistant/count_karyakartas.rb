module Assistant
  class CountKaryakartas
    def self.tool_name = "count_karyakartas"
    def self.available_to?(user) = user.role.can_access?("ground_reports")

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Count local karyakartas recorded on one village.",
          parameters: CountBeneficiaries.place_parameters
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("place_name", "place_kind")
    end

    def self.call(user:, place:, arguments: nil, client: nil)
      raise VillageOnly unless place.is_a?(Village)

      people = GroundReports::VillageLocalKaryakarta.where(village: place).order(:id)
      Answers.karyakartas(
        count: people.count,
        people: people.map { |person| Answers.person_label(name: person.name, phone: person.phone) },
        place: place.display_name,
        link_path: Rails.application.routes.url_helpers.ground_reports_village_path(place)
      )
    end
  end
end
