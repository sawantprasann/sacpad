module Assistant
  class PrRecordsLookup
    def self.tool_name = "pr_records"
    def self.place_mode = :none
    def self.available_to?(user) = user.role.can_access?("pr")

    def self.schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: "PR Records menu. How many records, and the recent headlines. Optional category or words from the title. No place is needed.",
          parameters: {
            type: "object",
            properties: {
              category: { type: "string", description: "PR category name. Leave empty for every category." },
              query: { type: "string", description: "Words to match in the headline. Leave empty for the full list." }
            }
          }
        }
      }
    end

    def self.sanitize(arguments)
      arguments.to_h.stringify_keys.slice("category", "query")
    end

    def self.call(user:, place: nil, arguments: {}, client: nil)
      relation = Pundit.policy_scope(user, PrRecord).includes(entries: :pr_category)
      category = category_for(arguments.to_h["category"])
      if category
        relation = relation.where(id: PrRecordEntry.where(pr_category_id: category.id).select(:pr_record_id))
      end
      query = arguments.to_h["query"].to_s.strip
      if query.present?
        term = "%#{PrRecord.sanitize_sql_like(query)}%"
        relation = relation.where("pr_records.title ILIKE ?", term)
      end
      records = relation.order(updated_at: :desc).limit(8).to_a
      lines = [ I18n.t("assistant.answers.pr.total", count: relation.count) ]
      records.each do |record|
        lines << "#{record.title} · #{record.category_names.join(", ").presence || I18n.t("assistant.none")}"
      end
      lines << I18n.t("assistant.answers.pr.none") if records.empty?
      path = Rails.application.routes.url_helpers.pr_records_path
      path = Rails.application.routes.url_helpers.pr_records_path(category: category.slug) if category
      Answers.report(lines, link_path: path, link_label: I18n.t("assistant.open_list"))
    end

    def self.category_for(name)
      text = name.to_s.squish.downcase
      return if text.blank?

      PrCategory.active.find { |category| category.name.to_s.downcase == text || category.slug == text.tr(" ", "-") }
    end
  end
end
