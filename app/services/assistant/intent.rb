module Assistant
  # qwen3:0.6b mixes similar village counts. When the question names one menu,
  # that menu wins over the tool the model picked. Two menus named means no override.
  class Intent
    RULES = [
      [ "count_beneficiaries", %w[beneficiary beneficiaries लाभार्थी] ],
      [ "count_karyakartas", %w[karyakarta karyakartas कार्यकर्ते] ],
      [ "local_admin_contact", %w[sarpanch सरपंच] ],
      [ "list_voters", %w[voter voters मतदार displeased pleased] ],
      [ "past_result", [ "past result", "मागील निकाल" ] ],
      [ "cadre_activities", [ "cadre", "leadership meet", "one to one", "one-to-one", "program by party", "कार्यकर्ता कार्यक्रम" ] ],
      [ "draft_speech", %w[speech भाषण] ],
      [ "pr_records", [ "pr record", "press release", "प्रसिद्धी" ] ],
      [ "social_pages", [ "social media", "सोशल मीडिया" ] ],
      [ "ground_snapshot", [ "ground report", "मैदानी अहवाल" ] ],
      [ "booth_status", [ "booth management", "booth status" ] ]
    ].freeze

    def self.tool_name(question)
      text = PlaceFinder.fold(question)
      hits = RULES.select { |_name, phrases| phrases.any? { |phrase| text.include?(PlaceFinder.fold(phrase)) } }
      hits.first.first if hits.one?
    end

    def self.all?(question)
      text = PlaceFinder.fold(question)
      %w[all every सर्व सगळे सगळ्या सगळ].any? do |word|
        text.match?(/(?<![\p{L}\p{N}])#{Regexp.escape(PlaceFinder.fold(word))}(?![\p{L}\p{N}])/)
      end
    end
  end
end
