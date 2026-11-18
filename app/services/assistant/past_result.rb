module Assistant
  class PastResult
    def self.tool_name = "past_result"
    def self.place_mode = :none
    def self.available_to?(_user) = true

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Past result menu. Winner, party, margin, and candidates for this constituency. No place is needed.",
          parameters: {
            type: "object",
            properties: {
              year: { type: "integer", description: "Election year. Leave empty for the latest stored result." }
            }
          }
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("year")
    end

    def self.call(user:, place: nil, arguments: {}, client: nil)
      scope = ConstituencyElection.for_organization(user.organization)
      year = arguments.to_h["year"].to_i
      election = year.positive? ? scope.find_by(year: year) : scope.first
      return Answers.report([ I18n.t("assistant.answers.past_result.none") ]) if election.blank?

      winner = election.winning_candidate
      lines = [
        election.heading,
        election.result_label,
        (I18n.t("assistant.answers.past_result.margin", votes: election.margin_votes, percent: election.margin_percent) if election.margin_votes)
      ]
      if winner
        lines << I18n.t(
          "assistant.answers.past_result.winner",
          name: winner.candidate_name,
          party: winner.party&.name,
          votes: winner.votes
        )
      end
      election.candidates.first(5).each do |candidate|
        lines << "#{candidate.candidate_name} · #{candidate.party&.name} · #{candidate.votes}"
      end
      Answers.report(lines, link_path: Rails.application.routes.url_helpers.election_result_path(election_year: election.year), link_label: I18n.t("assistant.open_result"))
    end
  end
end
