module Eci
  # Pull one Lok Sabha's assemblies from the Election Commission.
  #
  # Assemblies come from the district list and are kept only when their parliamentary
  # number matches this Lok Sabha. Roll PDFs are queued later, from each assembly's
  # first and last part.
  class ImportLoksabha
    class Error < StandardError; end

    CODE = /\A[A-Za-z0-9]+\z/

    Result = Struct.new(:assemblies, :read_pdfs, keyword_init: true) do
      def summary(name)
        text = "Fetched #{assemblies} #{'assembly'.pluralize(assemblies)} for #{name}."
        text += " Roll PDFs are queued for assemblies with a first and last part." if read_pdfs
        text
      end
    end

    def initialize(loksabha, client: Client.new, enqueue_voters: true)
      @loksabha = loksabha
      @client = client
      @enqueue_voters = enqueue_voters
    end

    def call
      state_cd = required_code(@loksabha.state&.cd, "This Lok Sabha's state needs an Election Commission code.")
      district_cd = required_code(@loksabha.district&.cd, "This Lok Sabha needs a district with an Election Commission code.")
      pc_no = @loksabha.constituency_no.to_s.strip
      raise Error, "This Lok Sabha needs a constituency number so its assemblies can be matched." if pc_no.blank?

      matches = assemblies_for(state_cd, district_cd).select { |ac| same_number?(ac["pcNo"], pc_no) }
      raise Error, "No assemblies found for constituency #{pc_no} in this district." if matches.empty?

      assemblies = 0
      Loksabha.transaction do
        matches.each do |ac|
          import_assembly(ac)
          assemblies += 1
        end
      end

      read_pdfs = @enqueue_voters && assemblies.positive?
      ImportLoksabhaVotersJob.perform_later(@loksabha.id) if read_pdfs
      Result.new(assemblies: assemblies, read_pdfs: read_pdfs)
    end

    private

    def assemblies_for(state_cd, district_cd)
      list = @client.assemblies(district_cd)
      return list if list.any? || !district_cd.match?(/\A\d+\z/)

      match = @client.districts(state_cd).find { |district| same_number?(district["districtNo"], district_cd) }
      raise Error, "No Election Commission district matches code #{district_cd}." unless match

      @client.assemblies(match["districtCd"])
    end

    def required_code(value, blank_message)
      code = value.to_s.strip
      raise Error, blank_message if code.blank?
      raise Error, "#{code} is not a valid Election Commission code." unless code.match?(CODE)

      code
    end

    def same_number?(left, right)
      a = left.to_s.strip
      b = right.to_s.strip
      return false if a.empty? || b.empty?
      return true if a == b

      a.match?(/\A\d+\z/) && b.match?(/\A\d+\z/) && a.to_i == b.to_i
    end

    def import_assembly(ac)
      number = ac["asmblyNo"]
      raise Error, "An assembly was returned without a number." if number.blank?

      assembly = @loksabha.assemblies.find_or_initialize_by(constituency_no: number.to_s)
      assembly.name = ac["asmblyName"].to_s.strip.presence || "Assembly #{number}"
      assembly.save!
    end
  end
end
