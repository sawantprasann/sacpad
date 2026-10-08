require "open3"
require "json"

module Eci
  # Download one booth's published roll PDF and read voters with script/eroll/extract_pdf.rb.
  class ImportBoothVoters
    class Error < StandardError; end

    SCRIPT = Rails.root.join("script/eroll/extract_pdf.rb").to_s.freeze
    UPSERT_BATCH = 500
    UPSERT_COLUMNS = %i[
      first_name middle_name last_name age house_no gender
      booth_id state_id loksabha_id assembly_id village_id
    ].freeze

    def initialize(booth, downloader: nil, extractor: nil)
      @booth = booth
      @downloader = downloader
      @extractor = extractor
    end

    def call
      load_geography!
      assembly = @booth.village.assembly
      loksabha = assembly.loksabha
      url = pdf_url(loksabha.state.cd, assembly.constituency_no, @booth.number)
      saved = 0

      Dir.mktmpdir("eroll") do |dir|
        path = File.join(dir, "part.pdf")
        status = download(url, path)
        return 0 if status == :missing
        raise Error, "Could not download the roll PDF for booth #{@booth.number}." if status == :failed

        payload = extract(path)
        apply_cover(payload["cover"], loksabha)
        saved = save_voters(payload["voters"] || [], loksabha, assembly)
      end
      saved
    end

    def pdf_url(state_cd, ac_number, part_number)
      state = state_cd.to_s.upcase
      ac = ac_number.to_i
      part = part_number.to_i
      "https://voters.eci.gov.in/eroll/2026/#{state.downcase}/sir-draftroll/#{ac}/" \
        "2026-EROLLGEN-#{state}-#{ac}-SIR-DraftRoll-Revision1-ENG-#{part}-WI.pdf"
    end

    private

    def load_geography!
      return if geography_loaded?

      @booth = Booth.includes(village: { assembly: { loksabha: [ :state, :district ] } }).find(@booth.id)
    end

    def geography_loaded?
      village = @booth.association(:village)
      return false unless village.loaded? && village.target

      assembly = village.target.association(:assembly)
      return false unless assembly.loaded? && assembly.target

      loksabha = assembly.target.association(:loksabha)
      return false unless loksabha.loaded? && loksabha.target

      loksabha.target.association(:state).loaded? && loksabha.target.association(:district).loaded?
    end

    def download(url, path)
      return @downloader.call(url, path) if @downloader

      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 90) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
      code = response.code.to_i
      return :missing if code == 404
      return :failed unless code == 200

      File.binwrite(path, response.body)
      :ok
    rescue StandardError => e
      raise Error, "Could not download the roll PDF (#{e.message})."
    end

    def extract(path)
      return @extractor.call(path) if @extractor

      raise Error, "Voter extract script is missing from this app." unless File.file?(SCRIPT)

      stdout, stderr, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s },
        RbConfig.ruby, "-rbundler/setup", SCRIPT, "--pdf", path
      )
      raise Error, script_failure(stderr) unless status.success?

      JSON.parse(stdout)
    rescue JSON::ParserError
      raise Error, "The voter extract script did not return voter data."
    end

    def script_failure(stderr)
      lines = stderr.to_s.lines.map(&:strip).reject(&:empty?)
      lines.find { |line| !line.start_with?("from ", "Ignoring ") } ||
        "The voter extract script failed."
    end

    def apply_cover(cover, loksabha)
      return if cover.blank?

      @booth.update!(
        name: cover["Polling Station No. and Name"].presence,
        address: cover["Polling Station Address"].presence,
        station_type: cover["Type of Polling Station"].presence
      )
      assign_village(cover, loksabha)
    end

    def assign_village(cover, loksabha)
      village = @booth.village
      village.police_station = cover["Police Station"].presence if cover["Police Station"].present?
      village.pin_code = cover["Pin Code"].presence if cover["Pin Code"].present?
      taluka = taluka_for(cover["Taluka"].presence, loksabha)
      village.taluka = taluka if taluka && village.taluka_id != taluka.id
      village.save! if village.changed?
    end

    def taluka_for(name, loksabha)
      district = loksabha.district
      return if name.blank? || district.nil?

      district.talukas.find_or_create_by!(name: name)
    end

    def save_voters(voters, loksabha, assembly)
      rows = voter_rows(voters, loksabha, assembly)
      return 0 if rows.empty?

      rows.each_slice(UPSERT_BATCH) do |slice|
        Voter.upsert_all(slice, unique_by: :voter_id, update_only: UPSERT_COLUMNS)
      end
      rows.size
    end

    def voter_rows(voters, loksabha, assembly)
      village_id = @booth.village.id
      by_epic = {}
      voters.each do |row|
        epic = row["epic"].to_s.strip
        next if epic.blank?

        names = split_name(row["name"])
        by_epic[epic] = {
          voter_id: epic,
          first_name: names[:first],
          middle_name: names[:middle],
          last_name: names[:last],
          age: integer_or_nil(row["age"]),
          house_no: blank_to_nil(row["house"]),
          gender: blank_to_nil(row["gender"]),
          booth_id: @booth.id,
          state_id: loksabha.state_id,
          loksabha_id: loksabha.id,
          assembly_id: assembly.id,
          village_id: village_id
        }
      end
      by_epic.values
    end

    def blank_to_nil(value)
      text = value.to_s.strip
      return if text.blank? || text == "N/A"

      text
    end

    def integer_or_nil(value)
      Integer(value, exception: false)
    end

    def split_name(name)
      parts = name.to_s.split
      return { first: "Unknown", middle: nil, last: "Unknown" } if parts.empty?
      return { first: parts[0], middle: nil, last: parts[0] } if parts.one?
      return { first: parts[0], middle: nil, last: parts[1] } if parts.length == 2

      { first: parts[0], middle: parts[1..-2].join(" "), last: parts[-1] }
    end
  end
end
