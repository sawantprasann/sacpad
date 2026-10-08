module Console
  class VillagesController < ReferenceController
    self.managed_model = Village
    self.managed_fields = %i[assembly_id taluka_id name]
    self.managed_title = "Village"
  end
end
