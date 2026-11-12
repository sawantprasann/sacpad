module KitchenCabinet
  # Village-scoped voter lookup for a ticket.
  # An exact full-name match still links a voter when the typed name is already correct.
  # The create form uses +suggest+, which returns a short page of partial name matches
  # so a spelling mistake can be picked from the village roll instead of missing entirely.
  class VoterMatch
    SUGGESTION_LIMIT = 20

    def self.for_ticket(ticket)
      name = normalize(ticket.person_name)
      villages = villages_named(ticket.organization, ticket.village)
      return [] if name.blank? || villages.none?

      Voter.where(village_id: villages.select(:id)).includes(:booth, :village).select do |voter|
        normalize(voter.name) == name
      end
    end

    # Partial name search inside one village. A query shorter than two characters
    # returns nothing, so opening the village does not load its whole roll.
    def self.suggest(organization:, village_name:, query:, limit: SUGGESTION_LIMIT)
      words = query.to_s.squish
      villages = villages_named(organization, village_name)
      return { voters: [], truncated: false } if words.length < 2 || villages.none?

      rows = Voter.where(village_id: villages.select(:id))
                  .matching_name(words)
                  .includes(:booth)
                  .order(:sr_no, :id)
                  .limit(limit + 1)
                  .to_a
      { voters: rows.first(limit), truncated: rows.length > limit }
    end

    def self.in_village?(organization, village_name, voter)
      return false if voter.nil?

      villages_named(organization, village_name).where(id: voter.village_id).exists?
    end

    def self.villages_named(organization, village_name)
      village_name = village_name.to_s.strip
      return Village.none if organization.nil? || village_name.blank?

      organization.villages.where("LOWER(villages.name) = ?", village_name.downcase)
    end

    def self.normalize(value)
      value.to_s.squish.downcase
    end
  end
end
