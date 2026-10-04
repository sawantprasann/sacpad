module Console
  class LoksabhasController < ReferenceController
    self.managed_model = Loksabha
    self.managed_fields = %i[state_id name]
    self.managed_title = "Loksabha"
  end
end
