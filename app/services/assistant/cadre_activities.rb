module Assistant
  class CadreActivities
    def self.tool_name = "cadre_activities"
    def self.place_mode = :optional
    def self.available_to?(user) = user.role.can_access?("cadre_program")

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "Cadre Program menu: Program By Party, Leadership Meets, Party Programs Hosted, Personal Program, and One To One. Counts and recent rows. Place is optional.",
          parameters: {
            type: "object",
            properties: CountBeneficiaries.place_parameters[:properties].merge(
              category: {
                type: "string",
                enum: CadreProgram::CadreActivity::CATEGORY_LABELS.keys,
                description: "Leave empty for every category."
              }
            )
          }
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("place_name", "place_kind", "category")
    end

    def self.call(user:, place: nil, arguments: {}, client: nil)
      category = normalize_category(arguments.to_h["category"])
      relation = Pundit.policy_scope(user, CadreProgram::CadreActivity)
      relation = relation.where(category: category) if category
      relation = located(relation, place) if place
      ids = relation.distinct.pluck(:id)
      counts = CadreProgram::CadreActivity.where(id: ids).group(:category).count
      rows = CadreProgram::CadreActivity.where(id: ids)
                     .includes(:program, :leadership_meet, :party_program_hosted, one_to_one: :karyakarta_user)
                     .order(created_at: :desc).limit(8)
      lines = [ I18n.t("assistant.answers.cadre.total", count: counts.values.sum) ]
      counts.each do |key, count|
        lines << "#{CadreProgram::CadreActivity.localized_category(key)}: #{count}"
      end
      rows.each do |activity|
        lines << "#{activity.category_label}: #{activity.detail_headline.presence || activity.impact_notes.to_s.squish.truncate(120)}"
      end
      lines << I18n.t("assistant.answers.cadre.none") if counts.values.sum.zero?
      path = Rails.application.routes.url_helpers.cadre_program_activities_path
      path = Rails.application.routes.url_helpers.cadre_program_activities_path(category: category) if category
      Answers.report(lines, link_path: path, link_label: I18n.t("assistant.open_list"))
    end

    def self.normalize_category(value)
      text = value.to_s.squish.downcase
      return if text.blank?

      CadreProgram::CadreActivity::CATEGORY_LABELS.each do |key, label|
        return key if key == text.tr(" ", "_") || label.downcase == text
      end
      nil
    end

    def self.located(relation, place)
      names = case place
      when Village then [ place.name, place.native_name ]
      when Booth then [ place.village.name, place.village.native_name ]
      when Taluka
        place_villages = Village.where(taluka_id: place.id)
        place_villages.flat_map { |village| [ village.name, village.native_name ] }
      else
        []
      end.compact_blank.map(&:downcase).uniq
      return relation.none if names.empty?

      relation.left_joins(:program, :party_program_hosted).where(
        "LOWER(cadre_activity_programs.location) IN (:names) OR LOWER(cadre_activity_party_program_hosteds.location) IN (:names)",
        names: names
      )
    end
  end
end
