module Imports
  # Report sheet: village, issue, resolution, reported_at. Owner and organization
  # come from the importer, never from the sheet.
  class GroundReportImporter < BaseImporter
    private

    def required_headers
      %w[village issue]
    end

    def import_row(data)
      village = find_village(data["village"])
      return "Village was not found in this constituency" if village.nil?

      reported_at = parse_date(data["reported_at"])
      return "Reported at is not a date" if reported_at == :invalid

      report = GroundReports::GroundReport.new(
        organization: @organization,
        owner: @user,
        village: village,
        issue_text: data["issue"].to_s.strip,
        resolution_text: data["resolution"].to_s.strip.presence,
        reported_at: reported_at || Date.current
      )
      report.save ? nil : report.errors.full_messages.to_sentence
    end

    def parse_date(value)
      return nil if value.blank?
      return value.to_date if value.is_a?(Date) || value.is_a?(Time) || value.is_a?(DateTime)

      Date.parse(value.to_s)
    rescue Date::Error, ArgumentError
      :invalid
    end
  end
end
