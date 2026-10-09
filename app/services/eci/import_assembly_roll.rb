module Eci
  # Read an assembly's roll by part number. Each published PDF names its village.
  class ImportAssemblyRoll
    class Error < StandardError; end

    def initialize(assembly, downloader: nil, extractor: nil)
      @assembly = assembly
      @downloader = downloader
      @extractor = extractor
    end

    def call
      raise Error, "Set the first and last part before reading this roll." if part_range.nil?

      part_range.each { |part| import_part(part) }
      remove_empty_villages
    end

    def import_part(part)
      payload = payload_for(part)
      return false if payload.nil?

      cover = payload["cover"] || {}
      name = cover["Main Town or Village"].to_s.strip.presence || "Part #{part}"
      village = @assembly.villages.create_or_find_by!(name: name)
      booth = booth_for(part, village)
      ImportBoothVoters.new(booth, payload: payload).call
      true
    rescue ImportBoothVoters::Error => e
      Rails.logger.error("Assembly #{@assembly.id} part #{part} voter import failed: #{e.message}")
      true
    end

    private

    def payload_for(part)
      state_cd = @assembly.loksabha.state.cd
      url = ImportBoothVoters.pdf_url(state_cd, @assembly.constituency_no, part)
      Dir.mktmpdir("eroll") do |dir|
        path = File.join(dir, "part.pdf")
        status = download(url, path)
        return nil if status == :missing
        raise ImportBoothVoters::Error, "Could not download the roll PDF for part #{part}." if status == :failed

        extract(path)
      end
    end

    def download(url, path)
      return @downloader.call(url, path) if @downloader

      ImportBoothVoters.download(url, path)
    end

    def extract(path)
      return @extractor.call(path) if @extractor

      ImportBoothVoters.extract(path)
    end

    def part_range
      from = @assembly.first_part
      to = @assembly.last_part
      return if from.blank? || to.blank? || to < from

      from..to
    end

    def booth_for(part, village)
      booth = Booth.joins(:village).find_by(villages: { assembly_id: @assembly.id }, number: part.to_s)
      if booth
        booth.update!(village: village) if booth.village_id != village.id
        booth
      else
        village.booths.create!(number: part.to_s)
      end
    end

    def remove_empty_villages
      @assembly.villages.find_each do |village|
        next if Booth.where(village_id: village.id).exists? || Voter.where(village_id: village.id).exists?

        ActsAsTenant.without_tenant { village.reload.destroy }
      rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey
        nil
      end
    end
  end
end
