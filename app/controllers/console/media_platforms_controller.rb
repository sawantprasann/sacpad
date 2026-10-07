module Console
  # Media platform catalog (Story 4.1) — extensible list of platforms for PR records.
  # Reuses the Story 0.4 catalog-editor pattern. Admin-only, global scope.
  class MediaPlatformsController < ReferenceController
    self.managed_model = MediaPlatform
    self.managed_fields = %i[name slug active]
    self.managed_title = "Media Platform"
  end
end
