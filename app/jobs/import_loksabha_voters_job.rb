# Queues one voter sync for each assembly that has a first and last part.
class ImportLoksabhaVotersJob < ApplicationJob
  queue_as :default

  def perform(loksabha_id)
    Loksabha.find(loksabha_id).assemblies.where.not(first_part: nil).where.not(last_part: nil).find_each do |assembly|
      ImportAssemblyVotersJob.perform_later(assembly.id)
    end
  end
end
