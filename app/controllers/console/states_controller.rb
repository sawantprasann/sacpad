module Console
  class StatesController < ReferenceController
    self.managed_model = State
    self.managed_fields = %i[name cd]
    self.managed_title = "State"
  end
end
