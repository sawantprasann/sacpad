# Queues one voter sync for each assembly in a Lok Sabha.
class ImportLoksabhaVotersJob < ApplicationJob
  queue_as :default

  def perform(loksabha_id)
    Loksabha.find(loksabha_id).assemblies.ids.each do |assembly_id|
      ImportAssemblyVotersJob.perform_later(assembly_id)
    end
  end
end
