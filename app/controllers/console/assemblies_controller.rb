module Console
  class AssembliesController < ReferenceController
    self.managed_model = Assembly
    self.managed_fields = %i[loksabha_id taluka_id name constituency_no]
    self.managed_title = "Assembly"
  end
end
