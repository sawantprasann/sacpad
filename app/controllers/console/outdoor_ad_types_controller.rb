module Console
  # Outdoor ad type catalog (Story 4.1) — extensible list of ad types for Outdoor Media PR records.
  # Reuses the Story 0.4 catalog-editor pattern. Admin-only, global scope.
  class OutdoorAdTypesController < ReferenceController
    self.managed_model = OutdoorAdType
    self.managed_fields = %i[name slug active]
    self.managed_title = "Outdoor Ad Type"
  end
end
