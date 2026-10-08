module Eci
  # Pull one Lok Sabha's assemblies, villages, and booths from the Election Commission.
  #
  # Assemblies come from the district list and are kept only when their parliamentary
  # number matches this Lok Sabha. Each booth's part name is the village (Maharashtra
  # publishes the village alone; Karnataka appends it after a comma).
  class ImportLoksabha
    class Error < StandardError; end

    CODE = /\A[A-Za-z0-9]+\z/

    Result = Struct.new(:assemblies, :villages, :booths, keyword_init: true) do
      def summary(name)
        "Fetched #{assemblies} #{'assembly'.pluralize(assemblies)}, " \
          "#{villages} #{'village'.pluralize(villages)}, and " \
          "#{booths} #{'booth'.pluralize(booths)} for #{name}."
      end
    end

    def initialize(loksabha, client: Client.new)
      @loksabha = loksabha
      @client = client
    end

    def call
      state_cd = required_code(@loksabha.state&.cd, "This Lok Sabha's state needs an Election Commission code.")
      district_cd = required_code(@loksabha.district&.cd, "This Lok Sabha needs a district with an Election Commission code.")
      pc_no = @loksabha.constituency_no.to_s.strip
      raise Error, "This Lok Sabha needs a constituency number so its assemblies can be matched." if pc_no.blank?

      matches = assemblies_for(state_cd, district_cd).select { |ac| same_number?(ac["pcNo"], pc_no) }
      raise Error, "No assemblies found for constituency #{pc_no} in this district." if matches.empty?

      rows = matches.map do |ac|
        number = ac["asmblyNo"]
        raise Error, "An assembly was returned without a number." if number.blank?

        { ac: ac, parts: @client.parts(state_cd, number) }
      end

      assemblies = 0
      booths = 0
      village_ids = []
      Loksabha.transaction do
        rows.each do |row|
          imported = import_assembly(row[:ac], row[:parts])
          assemblies += 1
          booths += imported[:booths]
          village_ids.concat(imported[:village_ids])
        end
      end

      Result.new(assemblies: assemblies, villages: village_ids.uniq.size, booths: booths)
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

    def village_name(part_name)
      name = part_name.to_s.strip
      return if name.empty?

      name.include?(",") ? name.split(",").last.strip.presence : name
    end

    def import_assembly(ac, parts)
      assembly = @loksabha.assemblies.find_or_initialize_by(constituency_no: ac["asmblyNo"].to_s)
      assembly.name = ac["asmblyName"].to_s.strip.presence || "Assembly #{ac['asmblyNo']}"
      assembly.save!

      village_ids = []
      booths = 0
      parts.each do |part|
        number = part["partNumber"].to_s.strip
        next if number.blank?

        name = village_name(part["partName"]).presence || "Part #{number}"
        village = assembly.villages.find_or_create_by!(name: name)
        village_ids << village.id

        booth = Booth.joins(:village).find_by(villages: { assembly_id: assembly.id }, number: number)
        if booth
          booth.update!(village: village) if booth.village_id != village.id
        else
          village.booths.create!(number: number)
        end
        booths += 1
      end

      { village_ids: village_ids, booths: booths }
    end
  end
end
