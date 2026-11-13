# Background job for bulk voter import from CSV file
class VoterImportJob < ApplicationJob
  queue_as :default

  def perform(file_path, _admin_id = nil)
    results = VoterImportService.new(file_path).call
    Rails.logger.info("Voter import completed: #{results.inspect}")
  ensure
    # Clean up temporary file
    File.delete(file_path) if file_path && File.exist?(file_path)
  end
end
