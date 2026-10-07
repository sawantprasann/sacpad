module Imports
  # Shared Excel read for Ground Reports (Story 3.5). Roo is already a dependency.
  # Each data row is saved on its own so one bad row does not roll back the file.
  Result = Struct.new(:imported_count, :row_errors, keyword_init: true)

  class BaseImporter
    def initialize(import)
      @import = import
      @organization = import.organization
      @user = import.user
    end

    def call
      sheet = open_sheet
      return failure(1, "The file could not be read as an Excel workbook") unless sheet
      return failure(1, "The sheet has no header row") if sheet.last_row.nil?

      headers = sheet.row(1).map { |cell| normalize_header(cell) }
      missing = required_headers - headers
      return failure(1, "Missing columns: #{missing.join(', ')}") if missing.any?
      return failure(1, "The sheet has no data rows") if sheet.last_row < 2

      imported = 0
      errors = []
      2.upto(sheet.last_row) do |number|
        values = sheet.row(number)
        next if values.all?(&:blank?)

        message = import_row(headers.zip(values).to_h)
        if message
          errors << { "row" => number, "message" => message }
        else
          imported += 1
        end
      end
      Result.new(imported_count: imported, row_errors: errors)
    end

    private

    def open_sheet
      @import.file.open do |temp|
        Roo::Spreadsheet.open(temp.path, extension: :xlsx).sheet(0)
      end
    rescue Zip::Error, ArgumentError, Roo::Error
      nil
    end

    def failure(row, message)
      Result.new(imported_count: 0, row_errors: [ { "row" => row, "message" => message } ])
    end

    def normalize_header(cell)
      cell.to_s.strip.downcase.gsub(/\s+/, "_")
    end

    def find_village(name)
      @organization.villages.find_by(name: name.to_s.strip)
    end

    def required_headers
      raise NotImplementedError
    end

    def import_row(_data)
      raise NotImplementedError
    end
  end
end
