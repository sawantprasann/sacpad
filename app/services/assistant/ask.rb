module Assistant
  # Turns one typed question into a stored answer. The model picks a tool.
  # Rails runs the query and writes every count, name, and phone number.
  class Ask
    PLACE_TYPES = {
      "Village" => Village,
      "Taluka" => Taluka,
      "Booth" => Booth
    }.freeze

    def initialize(user:, conversation:, question:, client: OllamaClient.new, save_question: true, user_message: nil)
      @user = user
      @conversation = conversation
      @question = question.to_s.strip
      @client = client
      @finder = PlaceFinder.new(user)
      @save_question = save_question
      @user_message = user_message
    end

    def call
      if @save_question
        @user_message = conversation.messages.create!(organization: user.organization, speaker: :from_user, body: question)
      end
      outcome = build_outcome
      save_answer(outcome)
    rescue OllamaClient::Error => error
      Rails.logger.warn("Assistant Ollama failed: #{error.class}: #{error.message}")
      save_answer(Answers.unavailable)
    end

    private

    attr_reader :user, :conversation, :question, :client, :finder

    def build_outcome
      if (choice = pending_choice)
        return execute(choice.fetch(:tool), choice.fetch(:arguments), choice.fetch(:place))
      end

      named = Catalog.find(user, Intent.tool_name(question))
      return Answers.not_configured if !client.configured? && speech_or_unknown?(named)
      return Answers.no_access unless Catalog.available?(user)

      call = model_call(named)
      tool = named || Catalog.find(user, call&.name)
      return Answers.not_understood if tool.nil?

      arguments = tool.sanitize((call&.arguments || {}).merge(details_for(tool)))
      mentioned = finder.mentioned(question)
      if mentioned.status == :many
        remember_pending(tool, arguments, mentioned.candidates)
        return Answers.which_place(mentioned.candidates.map { |record| finder.choice_label(record) })
      end
      if tool.tool_name == "count_beneficiaries" && Intent.all?(question) && mentioned.status == :none
        return execute(tool, arguments, nil)
      end

      case (place = locate(tool, arguments))
      when :ask then Answers.ask_place
      when :missing then Answers.place_missing(arguments["place_name"])
      when Array
        remember_pending(tool, arguments, place)
        Answers.which_place(place.map { |record| finder.choice_label(record) })
      else
        execute(tool, arguments, place)
      end
    end

    def speech_or_unknown?(tool)
      tool.nil? || tool.tool_name == "draft_speech"
    end

    # A named menu is answered from the database. The model is asked only when
    # the question does not already name the place, because qwen3:0.6b follows
    # one sentence shape and otherwise returns no tool.
    def model_call(named)
      mentioned = named ? finder.mentioned(question) : nil
      mode = named.respond_to?(:place_mode) ? named.place_mode : :required if named
      return if named && (mentioned.status != :none || Intent.all?(question) || mode != :required)

      client.tool_call(messages: prompt, tools: Catalog.schemas_for(user))
    rescue OllamaClient::Error => error
      raise unless named

      Rails.logger.warn("Assistant Ollama failed: #{error.class}: #{error.message}")
      nil
    end

    def details_for(tool)
      text = PlaceFinder.fold(question)
      args = {}
      case tool.tool_name
      when "cadre_activities"
        CadreProgram::CadreActivity::CATEGORY_LABELS.each do |key, label|
          args["category"] = key if text.include?(PlaceFinder.fold(label))
        end
      when "list_voters"
        ListVoters::STATUSES.each { |status| args["sentiment"] = status if text.include?(status) }
      when "local_admin_contact"
        args["role"] = "sarpanch" if text.include?("sarpanch") || text.include?("सरपंच")
      when "count_beneficiaries"
        %w[in_progress closed blocked].each { |status| args["status"] = status if text.include?(status.tr("_", " ")) }
      end

      mentioned = finder.mentioned(question)
      if mentioned.status == :one
        place = mentioned.place
        args["place_name"] = place.is_a?(Booth) ? place.number.to_s : place.name
        args["place_kind"] = place.class.name.downcase
      end
      args
    end

    def locate(tool, arguments)
      mode = tool.respond_to?(:place_mode) ? tool.place_mode : :required
      return if mode == :none
      return if mode == :optional && arguments["place_name"].blank?

      resolve_place(arguments)
    end

    def execute(tool, arguments, place)
      outcome = tool.call(user: user, place: place, arguments: arguments, client: client)
      updates = { pending_tool: nil, pending_arguments: {}, pending_places: [] }
      updates[:place] = place if place
      conversation.update!(updates)
      ActivityLog.record!(
        actor: user,
        action: "assistant.#{tool.tool_name}",
        record: place,
        organization: user.organization
      )
      outcome.tool_name = tool.tool_name
      outcome.arguments = arguments
      outcome
    rescue VillageOnly
      Answers.village_only
    end

    def resolve_place(arguments)
      name = arguments["place_name"].to_s.strip
      kind = arguments["place_kind"].to_s.downcase
      kind = nil unless %w[village taluka booth].include?(kind)

      if name.blank?
        return conversation.place if conversation.place && finder.visible?(conversation.place)

        return :ask
      end

      found = finder.find(name: name, kind: kind)
      found = finder.find(name: name, kind: nil) if found.status == :none && kind
      case found.status
      when :one then found.place
      when :many then found.candidates
      else :missing
      end
    end

    def pending_choice
      return if conversation.pending_places.blank?

      places = conversation.pending_places
      folded = PlaceFinder.fold(question)
      chosen = places.find { |place| PlaceFinder.fold(place["label"]) == folded }
      chosen ||= places[question.to_i - 1] if question.match?(/\A\d+\z/)
      tool = Catalog.find(user, conversation.pending_tool)
      record = chosen && load_place(chosen)
      if tool.nil? || record.nil? || !finder.visible?(record)
        conversation.update!(pending_tool: nil, pending_arguments: {}, pending_places: [])
        return
      end

      { tool: tool, arguments: conversation.pending_arguments || {}, place: record }
    end

    def remember_pending(tool, arguments, records)
      conversation.update!(
        pending_tool: tool.tool_name,
        pending_arguments: arguments,
        pending_places: records.map { |record|
          { "type" => record.class.name, "id" => record.id, "label" => finder.choice_label(record) }
        }
      )
    end

    def load_place(payload)
      type = PLACE_TYPES[payload["type"]]
      return if type.nil?

      type.find_by(id: payload["id"])
    end

    def prompt
      known = conversation.place
      hint = if known && finder.visible?(known)
        "The current place is #{finder.choice_label(known)}. Leave place_name empty to reuse it."
      else
        "No place is selected. Leave place_name empty only when the user named none."
      end
      [
        {
          role: "system",
          content: "Pick one tool. The user may write in English or Marathi. #{hint} Do not invent counts, names, or phone numbers."
        },
        { role: "user", content: question }
      ]
    end

    def save_answer(outcome)
      conversation.messages.create!(
        organization: user.organization,
        speaker: :from_assistant,
        body: outcome.body,
        tool_name: outcome.tool_name,
        tool_arguments: outcome.arguments || {},
        draft: outcome.draft || false,
        link_path: outcome.link_path,
        link_label: outcome.link_label,
        details: outcome.details || {},
        reply_to: @user_message
      )
    end
  end
end
