module Console
  class TalukasController < ReferenceController
    self.managed_model = Taluka
    self.managed_fields = %i[name district_id]
    self.managed_title = "Taluka"
  end
end
