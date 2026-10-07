module Imports
  # Mock poll sheet: one row per respondent per politician. created_by is the importer.
  class MockPollImporter < BaseImporter
    private

    def required_headers
      %w[village politician respondent_name preference_basis vote_intent]
    end

    def import_row(data)
      village = find_village(data["village"])
      return "Village was not found in this constituency" if village.nil?

      politician = politician_for(data["politician"])
      return politician if politician.is_a?(String)

      basis = data["preference_basis"].to_s.strip.downcase
      return "Leaning must be individual or party" unless GroundReports::MockPollResponse.preference_bases.key?(basis)

      choice = vote_choice_for(data["vote_intent"])
      return "Vote must be yes, no, or undecided" if choice == :invalid

      survey = GroundReports::MockPollResponse.new(
        organization: @organization,
        created_by: @user,
        village: village,
        politician: politician,
        respondent_name: data["respondent_name"].to_s.strip,
        respondent_mobile: data["respondent_mobile"].to_s.strip.presence,
        preference_basis: basis,
        vote_choice: choice,
        note: data["note"].to_s.strip.presence
      )
      survey.save ? nil : survey.errors.full_messages.to_sentence
    end

    def politician_for(name)
      matches = Politician.where(name: name.to_s.strip).to_a
      return "Politician was not found" if matches.empty?
      return "Politician name matched more than one person" if matches.many?

      matches.first
    end

    def vote_choice_for(value)
      return "yes" if value == true
      return "no" if value == false

      text = value.to_s.strip.downcase
      return "undecided" if text.blank? || text == "undecided"
      return "yes" if %w[yes true y].include?(text)
      return "no" if %w[no false n].include?(text)

      :invalid
    end
  end
end
