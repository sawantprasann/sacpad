module Console
  class LoksabhasController < ReferenceController
    self.managed_model = Loksabha
    self.managed_fields = %i[state_id district_id name constituency_no]
    self.managed_title = "Loksabha"

    def fetch_roll
      record = managed_model.find(params[:id])
      result = Eci::ImportLoksabha.new(record).call
      redirect_to({ action: :index }, notice: result.summary(record.name))
    rescue Eci::ImportLoksabha::Error, Eci::Client::Error => e
      redirect_to({ action: :index }, alert: e.message)
    end
  end
end
