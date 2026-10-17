module Api
  # Accepts the JSON printed by script/eroll/extract_pdf.rb on a Mac and files that part.
  class RollsController < ActionController::API
    before_action :authenticate_roll_token!

    def create
      assembly = Assembly.find(params[:assembly_id])
      saved = Eci::ImportAssemblyRoll.new(assembly).store_payload(params[:part_number], roll_payload)
      booth = Booth.joins(:village).find_by!(villages: { assembly_id: assembly.id }, number: params[:part_number].to_s)
      render json: {
        assembly_id: assembly.id,
        part: params[:part_number].to_s,
        village: booth.village.name,
        saved: saved
      }, status: :created
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Assembly or booth was not found." }, status: :not_found
    rescue Eci::ImportBoothVoters::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("Roll import failed: #{e.class}: #{e.message}")
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

    def unsafe_hash(value)
      return {} if value.blank?
      return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)

      value.to_h
    end
  end
end
