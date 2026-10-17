module KitchenCabinet
  # Exact full-name match inside the ticket's village, limited to this organization's villages.
  # Names are encrypted, so the comparison happens in memory after the village is loaded.
  class VoterMatch
    def self.for_ticket(ticket)
      name = normalize(ticket.person_name)
      village_name = ticket.village.to_s.strip
      return [] if name.blank? || village_name.blank? || ticket.organization.nil?

      villages = ticket.organization.villages.where("LOWER(villages.name) = ?", village_name.downcase)
      return [] if villages.none?

      Voter.where(village_id: villages.select(:id)).includes(:booth, :village).select do |voter|
        normalize(voter.name) == name
      end
    end

    def self.normalize(value)
      value.to_s.squish.downcase
    end
  end
end
