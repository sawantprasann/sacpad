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

  ACTION_ICONS = {
    view: '<path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"/>',
    edit: '<path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10"/>',
    delete: '<path stroke-linecap="round" stroke-linejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"/>'
  }.freeze

  ACTION_ICON_CLASSES = {
    view: "action-icon action-icon-view",
    edit: "action-icon action-icon-edit",
    delete: "action-icon action-icon-delete"
  }.freeze

  def action_icon(name)
    paths = ACTION_ICONS.fetch(name.to_sym)
    %(<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">#{paths}</svg>).html_safe
  end

  def icon_action_link(action, url, label: nil, **html)
    label ||= action.to_s.capitalize
    link_to action_icon(action), url, icon_action_attrs(action, label).merge(html)
  end

  def icon_action_button(action, url, label: nil, method: nil, confirm: nil, **html)
    label ||= action.to_s.capitalize
    attrs = icon_action_attrs(action, label).merge(html)
    attrs[:data] = (attrs[:data] || {}).merge(turbo_confirm: confirm) if confirm.present?
    button_to(url, { method: method || :delete, form: { class: "inline-flex" } }.merge(attrs)) do
      action_icon(action)
    end
  end

  def icon_action_attrs(action, label)
    {
      class: ACTION_ICON_CLASSES.fetch(action.to_sym),
      title: label,
      aria: { label: label }
    }
  end

  # TailAdmin "Pagination with Icon": chevron buttons and a numbered series.
  # Pagy keeps #series protected; the view only needs the array.
  def pagination_series(pagy)
    pagy.send(:series)
  end

  PAGINATION_CHEVRONS = {
    previous: "M2.58203 9.99868C2.58174 10.1909 2.6549 10.3833 2.80152 10.53L7.79818 15.5301C8.09097 15.8231 8.56584 15.8233 8.85883 15.5305C9.15183 15.2377 9.152 14.7629 8.85921 14.4699L5.13911 10.7472L16.6665 10.7472C17.0807 10.7472 17.4165 10.4114 17.4165 9.99715C17.4165 9.58294 17.0807 9.24715 16.6665 9.24715L5.14456 9.24715L8.85919 5.53016C9.15199 5.23717 9.15184 4.7623 8.85885 4.4695C8.56587 4.1767 8.09099 4.17685 7.79819 4.46984L2.84069 9.43049C2.68224 9.568 2.58203 9.77087 2.58203 9.99715C2.58203 9.99766 2.58203 9.99817 2.58203 9.99868Z",
    next: "M17.4165 9.9986C17.4168 10.1909 17.3437 10.3832 17.197 10.53L12.2004 15.5301C11.9076 15.8231 11.4327 15.8233 11.1397 15.5305C10.8467 15.2377 10.8465 14.7629 11.1393 14.4699L14.8594 10.7472L3.33203 10.7472C2.91782 10.7472 2.58203 10.4114 2.58203 9.99715C2.58203 9.58294 2.91782 9.24715 3.33203 9.24715L14.854 9.24715L11.1393 5.53016C10.8465 5.23717 10.8467 4.7623 11.1397 4.4695C11.4327 4.1767 11.9075 4.17685 12.2003 4.46984L17.1578 9.43049C17.3163 9.568 17.4165 9.77087 17.4165 9.99715C17.4165 9.99763 17.4165 9.99812 17.4165 9.9986Z"
  }.freeze

  def pagination_chevron(direction)
    path = PAGINATION_CHEVRONS.fetch(direction)
    %(<svg class="fill-current" width="20" height="20" viewBox="0 0 20 20" fill="none" aria-hidden="true"><path fill-rule="evenodd" clip-rule="evenodd" d="#{path}"></path></svg>).html_safe
  end

  def pagination_arrow_class(disabled: false)
    if disabled
      "shadow-theme-xs flex cursor-not-allowed items-center justify-center rounded-lg border border-gray-200 bg-white p-2.5 text-gray-300 dark:border-gray-800 dark:bg-gray-900 dark:text-gray-600"
    else
      "shadow-theme-xs flex items-center justify-center rounded-lg border border-gray-300 bg-white p-2.5 text-gray-700 transition hover:bg-gray-50 hover:text-gray-800 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-400 dark:hover:bg-white/[0.03] dark:hover:text-gray-200"
    end
  end

  def pagination_page_class(current: false)
    if current
      "campaign-btn flex h-10 w-10 items-center justify-center rounded-lg text-sm font-medium text-white"
    else
      "pagination-page flex h-10 w-10 items-center justify-center rounded-lg text-sm font-medium text-gray-700 dark:text-gray-400"
    end
  end
end
