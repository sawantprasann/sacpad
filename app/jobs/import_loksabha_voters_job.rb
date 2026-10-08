# Reads each booth PDF for one Lok Sabha with the existing roll OCR script.
class ImportLoksabhaVotersJob < ApplicationJob
  def perform(loksabha_id)
    loksabha = Loksabha.includes(assemblies: { villages: :booths }).find(loksabha_id)
    loksabha.assemblies.each do |assembly|
      assembly.villages.each do |village|
        village.booths.each do |booth|
          Eci::ImportBoothVoters.new(booth).call
        rescue Eci::ImportBoothVoters::Error => e
          Rails.logger.error("Booth #{booth.id} voter import failed: #{e.message}")
        end
      end
    end
  end
end
