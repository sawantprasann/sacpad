module ApplicationHelper
  # --- Per-org party theming (UX-DR3) ---
  # Accent resolved from the signed-in user's org's current party; bounded + AA-safe.
  # Matches TailAdmin's brand-500 so the default (Independent org) accent is consistent with the theme.
  DEFAULT_ACCENT = "#465FFF".freeze

  def org_accent_color
    color = current_user&.organization&.current_party&.color.presence
    return DEFAULT_ACCENT unless color =~ /\A#?[0-9a-fA-F]{6}\z/

    color.start_with?("#") ? color : "##{color}"
  end

  # Auto-computed black/white foreground so an arbitrary party hex stays AA-legible.
  def org_accent_foreground
    hex = org_accent_color.delete("#")
    r, g, b = hex.scan(/../).map { |c| c.to_i(16) }
    luminance = (0.299 * r) + (0.587 * g) + (0.114 * b)
    luminance > 150 ? "#1A1208" : "#FFFFFF"
  end

  # --- Shared TailAdmin component class strings (keeps internal pages consistent) ---
  def ta_field_classes
    "h-11 w-full rounded-lg border border-gray-300 bg-transparent px-4 py-2.5 text-sm text-gray-800 " \
      "shadow-theme-xs focus:border-brand-300 focus:ring-3 focus:ring-brand-500/10 focus:outline-hidden " \
      "dark:border-gray-700 dark:bg-gray-900 dark:text-white/90"
  end

  def ta_label_classes
    "mb-1.5 block text-sm font-medium text-gray-700 dark:text-gray-400"
  end

  def ta_btn_primary
    "campaign-btn inline-flex items-center justify-center rounded-lg px-4 py-2.5 text-sm font-medium " \
      "text-white transition"
  end

  def ta_btn_secondary
    "inline-flex items-center justify-center rounded-lg border border-gray-300 bg-white px-4 py-2.5 " \
      "text-sm font-medium text-gray-700 transition hover:bg-gray-50 dark:border-gray-700 dark:bg-white/5 dark:text-white/80"
  end

  def ta_card_classes
    "rounded-2xl border border-gray-200 bg-white shadow-sm dark:border-gray-800 dark:bg-white/[0.03]"
  end

  def ta_page_title
    "text-xl font-semibold tracking-tight text-gray-900 dark:text-white/90"
  end

  def document_title
    raw = content_for(:title).to_s.sub(/\s*·\s*SAC-PAD\z/, "").strip
    return "SAC-PAD" if raw.blank?

    "#{raw} · SAC-PAD"
  end

  # --- Organization Dashboard widget composition (FR50/FR51) ---
  # Module widgets render only if the viewer's role can access that module; org-admin-only
  # widgets render for roles with the can_create_users (org_admin) capability.
  def dashboard_widgets_for(user)
    return [] unless user

    module_widgets = [
      { title: "Open tickets by status", mod: "kitchen_cabinet" },
      { title: "Recent cadre activity",  mod: "cadre_program" },
      { title: "Recent ground reports",  mod: "ground_reports" },
      { title: "RAG summary",            mod: "rag_mapping" },
      { title: "Reach trend",            mod: "social_media" }
    ].select { |w| user.role.can_access?(w[:mod]) }

    admin_widgets =
      if user.role.can_create_users?
        [
          { title: "Pending items needing attention", admin_only: true },
          { title: "Hierarchy & user count", admin_only: true },
          { title: "Recent deletions", admin_only: true }
        ]
      else
        []
      end

    module_widgets + admin_widgets
  end

  # Festive jewel tones for the organization dashboard. These are chrome only —
  # they are not the reserved RAG / sentiment palette.
  DASHBOARD_JEWELS = [
    { bar: "from-[#ff7a18] to-[#ffd60a]", chip: "bg-[#ff7a18]", ring: "ring-orange-100", wash: "bg-orange-50/80" },
    { bar: "from-[#0e7490] to-[#67e8f9]", chip: "bg-[#0e7490]", ring: "ring-cyan-100", wash: "bg-cyan-50/80" },
    { bar: "from-[#4338ca] to-[#c4b5fd]", chip: "bg-[#4338ca]", ring: "ring-indigo-100", wash: "bg-indigo-50/80" },
    { bar: "from-[#be185d] to-[#fda4af]", chip: "bg-[#be185d]", ring: "ring-rose-100", wash: "bg-rose-50/80" },
    { bar: "from-[#b45309] to-[#fcd34d]", chip: "bg-[#b45309]", ring: "ring-amber-100", wash: "bg-amber-50/80" },
    { bar: "from-[#7e22ce] to-[#f0abfc]", chip: "bg-[#7e22ce]", ring: "ring-fuchsia-100", wash: "bg-fuchsia-50/80" }
  ].freeze

  def dashboard_jewel(index)
    DASHBOARD_JEWELS[index.to_i % DASHBOARD_JEWELS.length]
  end

  # Campaign desk clock. Users are in India; the app time zone is still UTC.
  def dashboard_now
    Time.current.in_time_zone("Asia/Kolkata")
  end

  def dashboard_greeting
    hour = dashboard_now.hour
    if hour < 12
      "Good morning"
    elsif hour < 17
      "Good afternoon"
    else
      "Good evening"
    end
  end
end
