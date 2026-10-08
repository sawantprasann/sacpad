# Reads every booth PDF for one assembly and writes the voters into the roll table.
class ImportAssemblyVotersJob < ApplicationJob
  queue_as :default

  def perform(assembly_id)
    assembly = Assembly.includes(villages: :booths).find(assembly_id)
    assembly.villages.each do |village|
      village.booths.each do |booth|
        Eci::ImportBoothVoters.new(booth).call
      rescue Eci::ImportBoothVoters::Error => e
        Rails.logger.error("Booth #{booth.id} voter import failed: #{e.message}")
      end
    end
  end
end
