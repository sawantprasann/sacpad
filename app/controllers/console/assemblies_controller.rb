module Console
  class AssembliesController < ReferenceController
    self.managed_model = Assembly
    self.managed_fields = %i[loksabha_id name constituency_no]
    self.managed_title = "Assembly"

    def sync_voters
      record = managed_model.includes(loksabha: :state).find(params[:id])
      if record.constituency_no.blank? || record.loksabha&.state&.cd.blank?
        redirect_to({ action: :index }, alert: "This assembly needs a constituency number and its state's Election Commission code.")
        return
      end
      unless Booth.joins(:village).exists?(villages: { assembly_id: record.id })
        redirect_to({ action: :index }, alert: "This assembly has no booths yet. Fetch the Lok Sabha roll first.")
        return
      end

      ImportAssemblyVotersJob.perform_later(record.id)
      redirect_to({ action: :index }, notice: "Voter sync started for #{record.name}. Names are saved as each booth PDF is read.")
    end
  end
end
