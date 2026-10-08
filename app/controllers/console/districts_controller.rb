module Console
  class DistrictsController < ReferenceController
    self.managed_model = District
    self.managed_fields = %i[name state_id]
    self.managed_title = "District"
  end
end
