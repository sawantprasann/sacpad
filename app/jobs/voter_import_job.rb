# Background job for bulk voter import from CSV file
class VoterImportJob < ApplicationJob
  queue_as :default

  def perform(file_path, admin_id = nil)
    service = VoterImportService.new(file_path)
    results = service.call

    # Log results
    Rails.logger.info("Voter import completed: #{results.inspect}")

    # Notify admin if email provided
    if admin_id
      admin = Admin.find_by(id: admin_id)
      VoterImportMailer.import_complete(admin, results).deliver_later if admin
    end
  ensure
    # Clean up temporary file
    File.delete(file_path) if file_path && File.exist?(file_path)
  end
end
