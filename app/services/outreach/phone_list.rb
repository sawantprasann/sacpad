module Outreach
  # Turns a CSV of phone numbers into one list. Indian mobiles become 91XXXXXXXXXX.
  class PhoneList
    HEADER = /\A(mobile|phone|phones|number|numbers|contact|mob|name|whatsapp)\z/i

    def self.sample_csv
      "mobile\n9876543210\n9123456789\n"
    end

    def self.from_upload(uploaded)
      raise CreateCampaign::Empty if uploaded.blank?

      text = uploaded.read.to_s.dup
      text.force_encoding(Encoding::UTF_8)
      text = text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      uploaded.rewind if uploaded.respond_to?(:rewind)

      rows = CSV.parse(text, liberal_parsing: true)
      header = rows.first.to_a.any? { |cell| cell.to_s.strip.match?(HEADER) } && rows.first.to_a.none? { |cell| normalize(cell) }
      rows = rows.drop(1) if header

      phones = []
      skipped = 0
      rows.each do |row|
        phone = Array(row).lazy.filter_map { |cell| normalize(cell) }.first
        if phone
          phones << phone
        elsif row.to_a.any? { |cell| cell.to_s.strip.present? }
          skipped += 1
        end
      end
      [ phones.uniq, skipped ]
    rescue CSV::MalformedCSVError
      raise CreateCampaign::Empty
    end

    def self.normalize(value)
      digits = value.to_s.gsub(/\D/, "").sub(/\A0+/, "")
      digits = "91#{digits}" if digits.length == 10
      digits if digits.match?(/\A91[6-9]\d{9}\z/)
    end
  end
end
