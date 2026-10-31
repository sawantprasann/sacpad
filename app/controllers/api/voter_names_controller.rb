module Api
  # Hands a village's English voter names to an outside machine, then stores the
  # Marathi parts that machine sends back. The translation itself does not run here.
  class VoterNamesController < ActionController::API
    before_action :authenticate_roll_token!

    def villages
      district = District.find(params[:district_id])
      rows = Village.where(taluka_id: district.talukas.select(:id)).order(:id)
      render json: {
        district_id: district.id,
        villages: rows.map { |village| { id: village.id, name: village.name } }
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "District was not found." }, status: :not_found
    end

    def show
      village = Village.find(params[:village_id])
      voters = village.voters
      voters = voters.select { |voter| voter.native_first_name.blank? } if ActiveModel::Type::Boolean.new.cast(params[:missing])
      render json: {
        village_id: village.id,
        name: village.name,
        voters: voters.map { |voter| voter_name(voter) }
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Village was not found." }, status: :not_found
    end

    def update
      village = Village.find(params[:village_id])
      updated = 0
      missing = []

      PaperTrail.request(enabled: false) do
        Array(params[:voters]).each do |row|
          voter = village.voters.find_by(id: row[:id])
          if voter.nil?
            missing << row[:id]
            next
          end

          attrs = native_attrs(row)
          next if attrs.empty?

          voter.update!(attrs)
          updated += 1
        end
      end

      render json: { village_id: village.id, updated: updated, missing: missing }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Village was not found." }, status: :not_found
    end

    private

    def authenticate_roll_token!
      expected = ENV["SACPAD_ROLL_TOKEN"].to_s
      provided = request.authorization.to_s.sub(/\ABearer /, "")
      return if expected.present? &&
        ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(provided), Digest::SHA256.hexdigest(expected))

      render json: { error: "Unauthorized" }, status: :unauthorized
    end

    def voter_name(voter)
      {
        id: voter.id,
        first_name: voter.first_name,
        middle_name: voter.middle_name,
        last_name: voter.last_name
      }
    end

    def native_attrs(row)
      %w[native_first_name native_middle_name native_last_name].each_with_object({}) do |key, attrs|
        value = row[key].to_s.squish
        attrs[key] = value if value.present?
      end
    end
  end
end
