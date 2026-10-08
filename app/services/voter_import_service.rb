require "csv"

# Bulk import voters from CSV file. Voters are global (no org_id).
# Expected CSV columns: voter_id, first_name, last_name, middle_name, mobile, booth_id, state, loksabha, assembly, village
class VoterImportService
  BATCH_SIZE = 500
  REQUIRED_COLUMNS = %i[voter_id first_name last_name].freeze

  attr_reader :file_path, :results

  def initialize(file_path)
    @file_path = file_path
    @results = { created: 0, updated: 0, errors: [], total: 0 }
  end

  def call
    validate_file!
    rows = parse_csv
    import_rows(rows)
    results
  rescue StandardError => e
    results[:errors] << "Import failed: #{e.message}"
    results
  end

  private

  def validate_file!
    raise "File not found" unless File.exist?(file_path)
    raise "File is empty" if File.zero?(file_path)
  end

  def parse_csv
    rows = []
    CSV.foreach(file_path, headers: true) do |row|
      rows << row.to_h.symbolize_keys
    end
    rows
  end

  def import_rows(rows)
    results[:total] = rows.length

    # Validate all rows first
    valid_rows = rows.filter_map { |row| validate_and_prepare_row(row) }

    # Upsert in batches
    valid_rows.each_slice(BATCH_SIZE) do |batch|
      upsert_batch(batch)
    end
  end

  def validate_and_prepare_row(row)
    # Check required columns
    missing = REQUIRED_COLUMNS.select { |col| row[col].blank? }
    if missing.any?
      results[:errors] << "Row missing #{missing.join(', ')}: #{row.inspect}"
      return nil
    end

    # Prepare voter attributes
    {
      voter_id: row[:voter_id].to_s.strip,
      first_name: row[:first_name].to_s.strip,
      last_name: row[:last_name].to_s.strip,
      middle_name: row[:middle_name].to_s.strip.presence,
      mobile: row[:mobile].to_s.strip.presence,
      state: row[:state].to_s.strip.presence,
      loksabha: row[:loksabha].to_s.strip.presence,
      assembly: row[:assembly].to_s.strip.presence,
      village: row[:village].to_s.strip.presence,
      booth_id: find_or_nil_booth_id(row[:booth_id])
    }
  rescue StandardError => e
    results[:errors] << "Error processing row #{row.inspect}: #{e.message}"
    nil
  end

  def find_or_nil_booth_id(booth_id_or_number)
    return nil if booth_id_or_number.blank?

    booth_id = booth_id_or_number.to_i
    return booth_id if booth_id > 0 && Booth.exists?(booth_id)
    nil
  rescue StandardError
    nil
  end

  def upsert_batch(batch)
    update_only_columns = %i[first_name last_name middle_name mobile state loksabha assembly village booth_id]

    Voter.upsert_all(
      batch,
      unique_by: :voter_id,
      update_only: update_only_columns
    )

    # Count created vs updated (approximation)
    batch.each do |row|
      existing = Voter.find_by(voter_id: row[:voter_id])
      if existing&.updated_at.to_i > 1.second.ago.to_i
        results[:updated] += 1
      else
        results[:created] += 1
      end
    end
  rescue StandardError => e
    results[:errors] << "Batch import failed: #{e.message}"
  end
end
