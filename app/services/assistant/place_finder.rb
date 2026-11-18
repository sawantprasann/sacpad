module Assistant
  class VillageOnly < StandardError; end

  # Exact place match inside the villages, talukas, and booths this user can already see.
  class PlaceFinder
    Result = Struct.new(:status, :place, :candidates, keyword_init: true)

    def initialize(user)
      @user = user
    end

    def find(name:, kind: nil)
      query = fold(name)
      return Result.new(status: :none) if query.blank?

      matches = pool(kind).select { |record| names_for(record).any? { |value| fold(value) == query } }
      case matches.size
      when 0 then Result.new(status: :none)
      when 1 then Result.new(status: :one, place: matches.first)
      else Result.new(status: :many, candidates: matches)
      end
    end

    def visible?(record)
      case record
      when Village then villages.exists?(id: record.id)
      when Taluka then talukas.exists?(id: record.id)
      when Booth then booths.exists?(id: record.id)
      else false
      end
    end

    def choice_label(record)
      case record
      when Village
        duplicate = villages.where("LOWER(villages.name) = ?", record.name.downcase).where.not(id: record.id).exists?
        duplicate ? "#{record.display_name} · #{record.assembly.name}" : record.display_name
      when Taluka
        record.display_name
      when Booth
        "#{record.number} · #{record.village.display_name}"
      else
        record.to_s
      end
    end

    def self.fold(text)
      text.to_s.unicode_normalize(:nfkc).squish.downcase
    end

    private

    attr_reader :user

    def fold(text) = self.class.fold(text)

    def pool(kind)
      records = []
      records.concat(villages.includes(:assembly).to_a) if kind.nil? || kind == "village"
      records.concat(talukas.to_a) if kind.nil? || kind == "taluka"
      records.concat(booths.includes(:village).to_a) if kind.nil? || kind == "booth"
      records
    end

    def names_for(record)
      case record
      when Booth then [ record.number, record.name, record.native_name ]
      else [ record.name, record.native_name ]
      end.compact_blank
    end

    def villages
      user.visible_villages(user.organization.villages)
    end

    def talukas
      Taluka.where(id: villages.where.not(taluka_id: nil).select(:taluka_id))
    end

    def booths
      scope = Booth.where(village_id: villages.select(:id))
      scope = scope.where(id: user.booth_id) if user.booth_manager?
      scope
    end
  end
end
