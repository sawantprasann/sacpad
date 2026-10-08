require "open3"
require "json"

module Eci
  # Download one booth's published roll PDF and read voters with script/eroll/extract_pdf.rb.
  class ImportBoothVoters
    class Error < StandardError; end

    SCRIPT = Rails.root.join("script/eroll/extract_pdf.rb").to_s.freeze

    def initialize(booth, downloader: nil, extractor: nil)
      @booth = booth
      @downloader = downloader
      @extractor = extractor
    end

    def call
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

    def save_voters(voters, loksabha, assembly)
      village = @booth.village
      saved = 0
      voters.each do |row|
        epic = row["epic"].to_s.strip
        next if epic.blank?

        names = split_name(row["name"])
        voter = Voter.find_or_initialize_by(voter_id: epic)
        voter.assign_attributes(
          booth: @booth,
          first_name: names[:first],
          middle_name: names[:middle],
          last_name: names[:last],
          state: loksabha.state.name,
          loksabha: loksabha.name,
          assembly: assembly.name,
          village: village.name
        )
        voter.save!
        saved += 1
      end
      saved
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
