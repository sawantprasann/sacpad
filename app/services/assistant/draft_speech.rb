module Assistant
  class DraftSpeech
    def self.tool_name = "draft_speech"

    def self.available_to?(user)
      Catalog::MODULES.any? { |mod| user.role.can_access?(mod) }
    end

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Draft a visit speech for one village from the stored briefing. Village only.",
          parameters: CountBeneficiaries.place_parameters
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("place_name", "place_kind")
    end

    def self.call(user:, place:, arguments: nil, client: nil)
      raise VillageOnly unless place.is_a?(Village)
      raise OllamaClient::Error, "Ollama is not configured" unless client&.configured?

      briefing = Briefing.new(user: user, village: place).to_h
      language = I18n.locale == :mr ? "Marathi" : "English"
      text = client.complete(messages: [
        { role: "system", content: "Write a short speech for a visit to this village today. Use only the facts in the JSON. Skip any section that is missing. Do not invent names, numbers, or events. Write in #{language}." },
        { role: "user", content: JSON.generate(briefing) }
      ])
      raise OllamaClient::Error, "empty speech" if text.blank?

      Answers.speech(text.truncate(4000))
    end
  end
end
