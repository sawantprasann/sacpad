module Console
  class LoksabhasController < ReferenceController
    self.managed_model = Loksabha
    self.managed_fields = %i[state_id district_id name constituency_no]
    self.managed_title = "Loksabha"
  end
end
