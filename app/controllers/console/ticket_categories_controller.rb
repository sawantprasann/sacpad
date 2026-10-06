module Console
  # Kitchen Cabinet ticket-category catalog (Story 1.1) — the first module consumer of the
  # reusable Story 0.4 catalog editor. Admin-only, Console-only; categories are global.
  class TicketCategoriesController < ReferenceController
    self.managed_model = TicketCategory
    self.managed_fields = %i[name slug active display_order]
    self.managed_title = "Ticket Category"
  end
end
