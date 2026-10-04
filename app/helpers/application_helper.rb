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
    "inline-flex items-center justify-center rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-medium " \
      "text-white transition hover:bg-brand-600"
  end

  def ta_btn_secondary
    "inline-flex items-center justify-center rounded-lg border border-gray-300 bg-white px-4 py-2.5 " \
      "text-sm font-medium text-gray-700 transition hover:bg-gray-50 dark:border-gray-700 dark:bg-white/5 dark:text-white/80"
  end

  def ta_card_classes
    "rounded-2xl border border-gray-200 bg-white shadow-sm dark:border-gray-800 dark:bg-white/[0.03]"
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
end
