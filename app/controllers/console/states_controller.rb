module Console
  class StatesController < ReferenceController
    self.managed_model = State
    self.managed_fields = %i[name]
    self.managed_title = "State"
  end
end
