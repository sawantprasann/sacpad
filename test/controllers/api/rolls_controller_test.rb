require "test_helper"

class Api::RollsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["SACPAD_ROLL_TOKEN"]
    ENV["SACPAD_ROLL_TOKEN"] = "test-token"
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Satara", state: state, cd: "S1331")
    loksabha = Loksabha.create!(name: "Madha", state: state, district: district, constituency_no: "43")
    @assembly = loksabha.assemblies.create!(name: "Phaltan (SC)", constituency_no: "255")
  end

  teardown do
    ENV["SACPAD_ROLL_TOKEN"] = @previous_token
  end

  test "stores the posted roll on the village, booth, and voters" do
    post "/api/assemblies/#{@assembly.id}/parts/2",
      params: {
        cover: {
          "Main Town or Village" => "Padegaon",
          "Police Station" => "Lonnad",
          "Polling Station No. and Name" => "2 - Padegaon",
          "Polling Station Address" => "Padegaon school"
        },
        voters: [
          { epic: "SSE8212128", name: "Dhanesh Somnath Idate", age: "22", gender: "Male", serial: "1", house: "10" }
        ]
      },
      as: :json,
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Padegaon", body["village"]
    assert_equal 1, body["saved"]

    booth = Booth.joins(:village).find_by!(villages: { assembly_id: @assembly.id }, number: "2")
    assert_equal "Padegaon", booth.village.name
    assert_equal "Lonnad", booth.village.police_station
    assert_equal "2 - Padegaon", booth.name
    voter = Voter.find_by!(voter_id: "SSE8212128")
    assert_equal "Dhanesh", voter.first_name
    assert_equal booth.id, voter.booth_id
    assert_equal 22, voter.age
  end

  test "returns the import failure as json" do
    Eci::ImportAssemblyRoll.class_eval do
      alias_method :store_payload_without_stub, :store_payload unless method_defined?(:store_payload_without_stub)
      define_method(:store_payload) do |*_args|
        raise ActiveRecord::Encryption::Errors::Configuration, "Missing Active Record encryption credential: active_record_encryption.primary_key"
      end
    end

    post "/api/assemblies/#{@assembly.id}/parts/2",
      params: { cover: { "Main Town or Village" => "Padegaon" }, voters: [] },
      as: :json,
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :internal_server_error
    assert_equal "application/json", response.media_type
    assert_match "active_record_encryption.primary_key", JSON.parse(response.body)["error"]
  ensure
    Eci::ImportAssemblyRoll.class_eval do
      alias_method :store_payload, :store_payload_without_stub
    end
  end

  test "rejects a missing token" do
    post "/api/assemblies/#{@assembly.id}/parts/2",
      params: { cover: {}, voters: [] },
      as: :json

    assert_response :unauthorized
    assert_equal 0, Voter.count
  end
end
