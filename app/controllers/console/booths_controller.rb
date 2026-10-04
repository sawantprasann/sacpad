module Console
  class BoothsController < ReferenceController
    self.managed_model = Booth
    self.managed_fields = %i[village_id number]
    self.managed_title = "Booth"
  end
end
