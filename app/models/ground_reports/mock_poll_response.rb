module GroundReports
  # One survey answer about one politician (Story 3.4, FR30). Win-likelihood is grouped
  # from these rows when the village page loads. There is no stored tally.
  class MockPollResponse < ApplicationRecord
    self.table_name = "mock_poll_responses"

    include OrganizationScoped
    include SoftDeletable
    include VillageInConstituency

    belongs_to :village
    belongs_to :politician
    belongs_to :created_by, class_name: "User"

    enum :preference_basis, { individual: 0, party: 1 }, validate: true

    validates :respondent_name, presence: true
    validate :politician_in_organization

    # Form values. The column stays a nullable boolean: yes, no, or undecided.
    def vote_choice
      return "yes" if vote_intent == true
      return "no" if vote_intent == false
      return "undecided" if persisted?

      nil
    end

    def vote_choice=(value)
      self.vote_intent = case value.to_s
      when "yes" then true
      when "no" then false
      when "undecided" then nil
      end
    end

    def vote_label
      case vote_intent
      when true then "Yes"
      when false then "No"
      else "Undecided"
      end
    end

    def self.tally_for(village)
      counts = where(village_id: village.id).group(:politician_id, :vote_intent).count
      ids = counts.keys.map(&:first).uniq
      Politician.where(id: ids).order(:name).map do |politician|
        {
          politician: politician,
          yes: counts[[ politician.id, true ]].to_i,
          no: counts[[ politician.id, false ]].to_i,
          undecided: counts[[ politician.id, nil ]].to_i
        }
      end
    end

    def self.likely_winners(rows)
      top = rows.map { |row| row[:yes] }.max.to_i
      return [] if top.zero?

      rows.select { |row| row[:yes] == top }.map { |row| row[:politician] }
    end

    private

    def politician_in_organization
      return if politician_id.blank? || organization.blank?
      return if Politician.exists?(id: politician_id)

      errors.add(:politician, "is not in this organization")
    end
  end
end
