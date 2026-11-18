module Assistant
  module Answers
    module_function

    def text(key, **)
      Outcome.new(body: I18n.t("assistant.#{key}", **))
    end

    def not_configured = text("not_configured")
    def not_understood = text("not_understood")
    def no_access = text("no_access")
    def ask_place = text("ask_place")
    def unavailable = text("unavailable")
    def village_only = text("village_only")

    def place_missing(name)
      text("place_missing", name: name)
    end

    def which_place(labels)
      text("which_place", names: labels.join(", "))
    end

    def beneficiaries(count:, match:, place:, link_path:, names: [], status: nil, status_counts: nil)
      key = status ? "#{match}_status" : match
      body = I18n.t(
        "assistant.answers.beneficiaries.#{key}",
        count: count,
        place: place,
        status: I18n.t("assistant.ticket_status.#{status}", default: status)
      )
      if status.nil? && status_counts
        body = "#{body} #{I18n.t("assistant.answers.beneficiaries.breakdown", **status_counts.symbolize_keys)}"
      end
      body = "#{body} #{I18n.t("assistant.answers.beneficiaries.named", names: names.join(", "))}" if names.any?
      Outcome.new(
        body: body,
        link_path: link_path,
        link_label: (I18n.t("assistant.open_list") if link_path)
      )
    end

    def voters(count:, names:, sentiment:, place:, link_path:)
      label = I18n.t("assistant.sentiment.#{sentiment}") if sentiment
      prefix = sentiment ? "assistant.answers.voters" : "assistant.answers.voters.all"
      body = if count.zero?
        I18n.t("#{prefix}.zero", place: place, sentiment: label)
      elsif count <= names.size
        I18n.t("#{prefix}.some", place: place, count: count, sentiment: label, names: names.join(", "))
      else
        I18n.t("#{prefix}.more", place: place, count: count, shown: names.size, sentiment: label, names: names.join(", "))
      end
      Outcome.new(body: body, link_path: link_path, link_label: (I18n.t("assistant.open_list") if link_path))
    end

    def karyakartas(count:, people:, place:, link_path:)
      body = if count.zero?
        I18n.t("assistant.answers.karyakartas.zero", place: place)
      else
        I18n.t("assistant.answers.karyakartas.some", place: place, count: count, names: people.join(", "))
      end
      Outcome.new(body: body, link_path: link_path, link_label: (I18n.t("assistant.open_village") if link_path))
    end

    def sarpanch(contacts:, place:, link_path:)
      body = if contacts.empty?
        I18n.t("assistant.answers.sarpanch.none", place: place)
      elsif contacts.one?
        person = contacts.first
        if person[:phone].present?
          I18n.t("assistant.answers.sarpanch.one", place: place, name: person[:name], phone: person[:phone])
        else
          I18n.t("assistant.answers.sarpanch.one_without_phone", place: place, name: person[:name])
        end
      else
        list = contacts.map { |person| person_label(name: person[:name], phone: person[:phone]) }.join("; ")
        I18n.t("assistant.answers.sarpanch.many", place: place, list: list)
      end
      Outcome.new(body: body, link_path: link_path, link_label: (I18n.t("assistant.open_village") if link_path))
    end

    def speech(body)
      Outcome.new(body: body, draft: true)
    end

    def report(lines, link_path: nil, link_label: nil)
      Outcome.new(
        body: Array(lines).compact_blank.join("\n"),
        link_path: link_path,
        link_label: link_label
      )
    end

    def person_label(name:, phone: nil)
      return name if phone.blank?

      "#{name} (#{phone})"
    end
  end
end
