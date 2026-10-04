module Console
  class AssembliesController < ReferenceController
    self.managed_model = Assembly
    self.managed_fields = %i[loksabha_id name]
    self.managed_title = "Assembly"
  end
end
