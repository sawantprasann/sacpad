module Console
  # Bulk voter import from CSV — Global Voter table (Story 0.15 v2 + Epic 6)
  class VoterImportsController < BaseController
    def index
      @recent_imports = []  # TODO: Track import history in database
    end

    def new
    end

    def create
      file = params[:file]
      unless file.present?
        redirect_to console_voter_imports_path, alert: "No file selected."
        return
      end

      unless file.content_type.in?(%w[text/csv application/vnd.ms-excel])
        redirect_to console_voter_imports_path, alert: "File must be CSV format."
        return
      end

      # Save temp file and queue import job
      temp_path = Rails.root.join("tmp/voter_imports/#{SecureRandom.hex(8)}_#{file.original_filename}")
      FileUtils.mkdir_p(temp_path.dirname)
      file.tempfile.rewind
      FileUtils.copy(file.tempfile.path, temp_path)

      # Queue background job
      VoterImportJob.perform_later(temp_path.to_s, current_admin.id)

      redirect_to console_voter_imports_path, notice: "Import queued. You'll receive an email when complete."
    end
  end
end
