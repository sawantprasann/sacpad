module Eci
  # Writes Lok Sabha-language names for one part after the English roll is stored.
  # Place names land on the part's village, its taluka, that taluka's district, and
  # its police station. Each voter is found by voter_id.
  class ImportNativeNames
    class Error < StandardError; end

    def initialize(assembly)
      @assembly = assembly
    end

    def store_payload(part, payload)
      booth = booth_for(part)
      village = booth.village
      voter_updates = voter_updates_for(Array(payload["voters"]))

      ActiveRecord::Base.transaction do
        apply_native_name(village, payload["village"], "This part has no village.")
        apply_native_name(village.taluka, payload["taluka"], "This part has no taluka.")
        apply_native_name(district_for(village), payload["district"], "This part has no district.")
        apply_native_name(village.police_station_record, payload["police_station"], "This part has no police station.")
        voter_updates.each { |voter, attrs| voter.update!(attrs) }
      end

      voter_updates.size
    end

    private

    def booth_for(part)
      Booth.joins(:village).includes(village: [ :taluka, :police_station_record, { taluka: :district } ]).find_by!(
        villages: { assembly_id: @assembly.id },
        number: part.to_s
      )
    end

    def district_for(village)
      village.taluka&.district || village.assembly.loksabha.district
    end

    def apply_native_name(record, section, missing_message)
      native_name = text(section, "native_name")
      return if native_name.blank?
      raise Error, missing_message if record.nil?

      record.update!(native_name: native_name)
    end

    def voter_updates_for(rows)
      missing = []
      updates = []

      rows.each do |row|
        voter_id = text(row, "voter_id")
        next if row.blank?
        if voter_id.blank?
          missing << "(blank voter_id)"
          next
        end

        voter = Voter.find_by(voter_id: voter_id)
        unless voter && voter_in_assembly?(voter)
          missing << voter_id
          next
        end

        attrs = native_person_attrs(row)
        updates << [ voter, attrs ] if attrs.any?
      end

      raise Error, "Voters were not found in this assembly: #{missing.join(', ')}" if missing.any?

      updates
    end

    def voter_in_assembly?(voter)
      voter.assembly_id == @assembly.id || voter.village&.assembly_id == @assembly.id
    end

    def native_person_attrs(row)
      %w[native_first_name native_middle_name native_last_name].each_with_object({}) do |key, attrs|
        value = text(row, key)
        attrs[key] = value if value.present?
      end
    end

    def text(record, key)
      return if record.blank?

      value = record[key]
      value = record[key.to_sym] if value.nil? && record.respond_to?(:[])
      value.to_s.strip.presence
    end
  end
end
