# Downloads one roll PDF and files that part's village and voters.
class ImportAssemblyPartJob < ApplicationJob
  queue_as :default

  def perform(assembly_id, part)
    assembly = Assembly.includes(loksabha: [ :state, :district ]).find(assembly_id)
    Eci::ImportAssemblyRoll.new(assembly).import_part(part)
  end
end
