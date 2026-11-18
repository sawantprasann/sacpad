module Assistant
  class Catalog
    MODULES = %w[
      kitchen_cabinet cadre_program ground_reports pr
      voter_lists booth_management social_media
    ].freeze
    TOOLS = [
      PastResult,
      CountBeneficiaries,
      CadreActivities,
      GroundSnapshot,
      CountKaryakartas,
      LocalAdminContact,
      PrRecordsLookup,
      ListVoters,
      TalukaOverview,
      BoothStatus,
      SocialPages,
      DraftSpeech
    ].freeze

    def self.available?(user)
      return false unless user&.role

      MODULES.any? { |mod| user.role.can_access?(mod) } ||
        ConstituencyElection.for_organization(user.organization).exists?
    end

    def self.for(user)
      TOOLS.select { |tool| tool.available_to?(user) }
    end

    def self.schemas_for(user)
      self.for(user).map(&:schema)
    end

    def self.find(user, name)
      self.for(user).find { |tool| tool.tool_name == name.to_s }
    end
  end
end
