module Console
  class PartiesController < ReferenceController
    self.managed_model = Party
    self.managed_fields = %i[name abbreviation color]
    self.managed_title = "Party"
  end
end
