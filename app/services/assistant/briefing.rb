module Assistant
  # Facts Rails has already looked up. The speech model sees this hash and nothing else.
  class Briefing
    def initialize(user:, village:)
      @user = user
      @village = village
    end

    def to_h
      packet = { village: village.display_name, locale: I18n.locale.to_s }
      packet[:beneficiaries] = beneficiary_section if user.role.can_access?("kitchen_cabinet")
      packet[:displeased_voter_count] = displeased_count if user.role.can_access?("voter_lists")
      packet[:karyakarta_count] = karyakarta_count if user.role.can_access?("ground_reports")
      packet[:sarpanch] = sarpanch_section if user.role.can_access?("ground_reports")
      packet[:ground_reports] = report_section if user.role.can_access?("ground_reports")
      packet[:cadre] = cadre_section if user.role.can_access?("cadre_program")
      election = election_section
      packet[:election] = election if election.present?
      packet.reject { |_key, value| value.nil? || value == [] || value == "" }
    end

    private

    attr_reader :user, :village

    def beneficiary_section
      summary = CountBeneficiaries.summary_for(user, village)
      { count: summary[:count], matched_by: summary[:match] }
    end

    def displeased_count
      ListVoters.summary_for(user, village, "displeased")[:count]
    end

    def karyakarta_count
      GroundReports::VillageLocalKaryakarta.where(village: village).count
    end

    def sarpanch_section
      GroundReports::VillageLocalAdminContact.where(village: village).order(:id).filter_map do |contact|
        next unless LocalAdminContact.sarpanch?(contact.role_title)

        { name: contact.name, phone: contact.phone }.compact_blank
      end
    end

    def report_section
      Pundit.policy_scope(user, GroundReports::GroundReport).where(village: village).order(reported_at: :desc).limit(3).map do |report|
        { issue: report.issue_text.to_s.squish.truncate(400), resolution: report.resolution_text.to_s.squish.truncate(400).presence }.compact
      end
    end

    def cadre_section
      names = [ village.name, village.native_name ].compact_blank.map(&:downcase).uniq
      return [] if names.empty?

      Pundit.policy_scope(user, CadreProgram::CadreActivity)
        .left_joins(:program, :party_program_hosted)
        .where(
          "LOWER(cadre_activity_programs.location) IN (:names) OR LOWER(cadre_activity_party_program_hosteds.location) IN (:names)",
          names: names
        )
        .limit(10)
        .uniq(&:id)
        .first(5)
        .map do |activity|
          {
            category: activity.category,
            notes: activity.impact_notes.to_s.squish.truncate(400).presence,
            program: activity.program&.program_name || activity.party_program_hosted&.program_name,
            location: activity.program&.location || activity.party_program_hosted&.location
          }.compact
        end
    end

    def election_section
      election = ConstituencyElection.for_organization(user.organization).first
      return if election.blank?

      {
        year: election.year,
        result: election.result_label,
        margin_votes: election.margin_votes,
        margin_percent: election.margin_percent
      }.compact
    end
  end
end
