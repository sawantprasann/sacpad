module Console
  # PR category catalog (Story 4.1) — reuses the Story 0.4 catalog-editor pattern.
  # Admin-only, Console-only; categories are global and shared across orgs.
  class PrCategoriesController < ReferenceController
    self.managed_model = PrCategory
    self.managed_fields = %i[name slug active display_order]
    self.managed_title = "PR Category"
  end
end
