# Runs a Ground Reports workbook import inside the importer's organization (Story 3.5).
class ImportGroundReportsJob < ApplicationJob
  def perform(import_id)
    import = GroundReports::Import.unscoped.find(import_id)
    return if import.completed?

    ActsAsTenant.with_tenant(import.organization) do
      importer = import.mock_poll? ? Imports::MockPollImporter : Imports::GroundReportImporter
      result = importer.new(import).call
      import.update!(
        status: :completed,
        imported_count: result.imported_count,
        row_errors: result.row_errors
      )
    end
  end
end
