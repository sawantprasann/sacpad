module ElectionResultsHelper
  def console_election_result_path(election)
    constituency = election.constituency
    if constituency.is_a?(Assembly)
      console_loksabha_assembly_constituency_election_path(constituency.loksabha, constituency, election)
    else
      console_loksabha_constituency_election_path(constituency, election)
    end
  end

  def edit_console_election_result_path(election)
    constituency = election.constituency
    if constituency.is_a?(Assembly)
      edit_console_loksabha_assembly_constituency_election_path(constituency.loksabha, constituency, election)
    else
      edit_console_loksabha_constituency_election_path(constituency, election)
    end
  end

  def new_console_election_result_path(constituency)
    if constituency.is_a?(Assembly)
      new_console_loksabha_assembly_constituency_election_path(constituency.loksabha, constituency)
    else
      new_console_loksabha_constituency_election_path(constituency)
    end
  end

  def party_choice_label(party)
    party.abbreviation.present? ? "#{party.abbreviation} — #{party.name}" : party.name
  end

  def party_swatch(party)
    color = party&.color.to_s.strip
    color = "##{color}" unless color.start_with?("#")
    color.match?(/\A#[0-9a-fA-F]{6}\z/) ? color : "#d0d5dd"
  end

  def election_count(value)
    return "—" if value.nil?

    number_with_delimiter(value)
  end

  def election_percent(value)
    return "—" if value.nil?

    "#{number_with_precision(value, precision: 2)}%"
  end

  def election_change_tag(value, fresh: false)
    return content_tag(:span, t("election.fresh"), class: "text-gray-500") if fresh
    return "—" if value.nil?

    formatted = number_with_precision(value.abs, precision: 2)
    if value.negative?
      content_tag(:span, "▼ #{formatted}", class: "font-medium text-red-600")
    elsif value.positive?
      content_tag(:span, "▲ #{formatted}", class: "font-medium text-green-700")
    else
      formatted
    end
  end

  def election_outcome_sentence(election)
    winner = election.winning_candidate
    return if winner.blank?

    margin = election.margin_votes.present? ? t("election.by_votes", count: election_count(election.margin_votes)) : ""
    if election.gain? && election.gained_from_party
      from = election.gained_from_party.abbreviation.presence || election.gained_from_party.name
      t("election.took_seat", name: winner.candidate_name, from: from, margin: margin)
    else
      t("election.held_seat", name: winner.candidate_name, margin: margin)
    end
  end

  def election_result_line(election)
    if election.gain? && election.gained_from_party
      from = election.gained_from_party.abbreviation.presence || election.gained_from_party.name
      t("election.took_line", from: from)
    else
      t("election.held_line")
    end
  end

  # Vote-share donut. Stored party colors are often navy, gray, or near-white,
  # which wash out on the white card, so each slice gets a saturated color.
  ELECTION_PIE_COLORS = %w[
    #FF5A1F
    #2563EB
    #16A34A
    #E11D48
    #F59E0B
    #7C3AED
    #0891B2
    #DB2777
    #65A30D
    #4F46E5
  ].freeze

  def election_pie_color(index)
    ELECTION_PIE_COLORS[index % ELECTION_PIE_COLORS.length]
  end

  def election_share_slices(election)
    seen = Hash.new(0)
    election.candidates.each_with_index.map do |candidate, index|
      party = candidate.party.abbreviation.presence || candidate.party.name
      seen[party] += 1
      label = seen[party] > 1 ? "#{party} #{seen[party]}" : party
      [ label, candidate.vote_percent.to_f, election_pie_color(index) ]
    end
  end

  def election_bar_width(percent)
    value = percent.to_f
    value = 0 if value.negative?
    value = 100 if value > 100
    number_with_precision(value, precision: 2)
  end

  def election_result_nav?
    return @election_result_nav if defined?(@election_result_nav)

    constituency = current_user&.organization&.constituency
    @election_result_nav = constituency.present? && ConstituencyElection.for_constituency(constituency).exists?
  end

  def election_year_link_class
    "inline-flex items-center rounded-full bg-amber-50 px-3 py-1 text-xs font-semibold text-amber-900 ring-1 ring-amber-200 hover:bg-amber-100 dark:bg-white/10 dark:text-amber-100 dark:ring-amber-700/40"
  end

  def election_year_selected_class
    "inline-flex cursor-default items-center rounded-full bg-gray-900 px-3 py-1 text-xs font-semibold text-white"
  end

  def election_year_selected_style
    "background-color:#0b1f44;color:#ffffff"
  end

  def election_year_link_data
    # Frame-only navigation. data-turbo-action="advance" also starts a page visit
    # that does not redraw the body, and Chartkick destroys the new donut on
    # turbo:before-render. The year stays in the address bar from turbo:frame-load.
    { turbo_frame: "election-result" }
  end
end
