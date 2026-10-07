module ModuleIconHelper
  # Returns SVG icon for each module with consistent styling
  def module_icon(module_name, classes = "h-6 w-6")
    icons = {
      kitchen_cabinet: %(<svg class="#{classes}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>),
      cadre_program: %(<svg class="#{classes}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>),
      ground_reports: %(<svg class="#{classes}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>),
      pr_records: %(<svg class="#{classes}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><path d="M6 9h2M6 13h2M10 9h8M10 13h8"/></svg>),
      default: %(<svg class="#{classes}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="9" y1="9" x2="15" y2="9"/><line x1="9" y1="15" x2="15" y2="15"/></svg>),
    }

    icons[module_name.to_sym] || icons[:default]
  end

  # Returns module color for consistent branding
  def module_color(module_name)
    colors = {
      kitchen_cabinet: "text-blue-600 dark:text-blue-400",
      cadre_program: "text-purple-600 dark:text-purple-400",
      ground_reports: "text-green-600 dark:text-green-400",
      pr_records: "text-orange-600 dark:text-orange-400",
      default: "text-gray-600 dark:text-gray-400",
    }

    colors[module_name.to_sym] || colors[:default]
  end
end
