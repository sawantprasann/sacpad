module Api
  # Accepts the JSON printed by script/eroll/extract_pdf.rb on a Mac and files that part.
  class RollsController < ActionController::API
    before_action :authenticate_roll_token!

    def create
      assembly = Assembly.find(params[:assembly_id])
      saved = Eci::ImportAssemblyRoll.new(assembly).store_payload(params[:part_number], roll_payload)
      booth = Booth.joins(:village).find_by!(villages: { assembly_id: assembly.id }, number: params[:part_number].to_s)
      totals = elector_totals
      booth.update!(totals) if totals.any?
      render json: {
        assembly_id: assembly.id,
        part: params[:part_number].to_s,
        village: booth.village.name,
        saved: saved,
        male: booth.male_electors,
        female: booth.female_electors,
        others: booth.other_electors
      }, status: :created
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Assembly or booth was not found." }, status: :not_found
    rescue Eci::ImportBoothVoters::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("Roll import failed: #{e.class}: #{e.message}")
      render json: { error: e.message }, status: :internal_server_error
    end

    def native_names
      assembly = Assembly.find(params[:assembly_id])
      updated = Eci::ImportNativeNames.new(assembly).store_payload(params[:part_number], native_payload)
      booth = Booth.joins(:village).find_by!(villages: { assembly_id: assembly.id }, number: params[:part_number].to_s)
      render json: {
        assembly_id: assembly.id,
        part: params[:part_number].to_s,
        village: booth.village.name,
        updated: updated
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Assembly or booth was not found." }, status: :not_found
    rescue Eci::ImportNativeNames::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("Native name import failed: #{e.class}: #{e.message}")
      render json: { error: e.message }, status: :internal_server_error
    end

    private

    def authenticate_roll_token!
      expected = ENV["SACPAD_ROLL_TOKEN"].to_s
      provided = request.authorization.to_s.sub(/\ABearer /, "")
      return if expected.present? &&
        ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(provided), Digest::SHA256.hexdigest(expected))

      render json: { error: "Unauthorized" }, status: :unauthorized
    end

    def roll_payload
      body = params[:roll].presence || params
      {
        "cover" => unsafe_hash(body[:cover]),
        "voters" => Array(body[:voters]).map { |row| unsafe_hash(row) }
      }
    end

    # Sent totals override the cover. A missing total leaves the booth's current value.
    def elector_totals
      sources = [ params[:roll].presence, params ].compact
      totals = {}
      male = first_integer(sources, :total_male, :male)
      totals[:male_electors] = male unless male.nil?
      female = first_integer(sources, :total_female, :female)
      totals[:female_electors] = female unless female.nil?
      other = first_integer(sources, :total_other, :total_others, :other, :others)
      totals[:other_electors] = other unless other.nil?
      totals
    end

    def first_integer(sources, *keys)
      raw = sources.lazy.flat_map { |body| keys.map { |key| body[key] } }.find { |value| value.to_s.strip.present? }
      Integer(raw, exception: false)
    end

    def native_payload
      {
        "taluka" => unsafe_hash(params[:taluka]),
        "district" => unsafe_hash(params[:district]),
        "village" => unsafe_hash(params[:village]),
        "police_station" => unsafe_hash(params[:police_station]),
        "voters" => Array(params[:voters]).map { |row| unsafe_hash(row) }
      }
    end

    def unsafe_hash(value)
      return {} if value.blank?
      return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)

      value.to_h
    end
  end
end
