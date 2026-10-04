module ApplicationHelper
  # --- Per-org party theming (UX-DR3) ---
  # Accent resolved from the signed-in user's org's current party; bounded + AA-safe.
  DEFAULT_ACCENT = "#3C50E0".freeze

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
