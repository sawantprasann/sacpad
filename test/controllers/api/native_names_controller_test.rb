require "test_helper"

class Api::RollsNativeNamesTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["SACPAD_ROLL_TOKEN"]
    ENV["SACPAD_ROLL_TOKEN"] = "test-token"
    state = State.create!(name: "Maharashtra", cd: "S13")
    @district = District.create!(name: "Osmanabad", state: state)
    loksabha = Loksabha.create!(name: "Osmanabad", state: state, district: @district, native_locale: "mr")
    @assembly = loksabha.assemblies.create!(name: "Paranda")
    @taluka = @district.talukas.create!(name: "Bhum")
    @village = @assembly.villages.create!(name: "Antarwali", taluka: @taluka, police_station: "Ambhi")
    @booth = @village.booths.create!(number: "1")
    @voter = Voter.create!(
      voter_id: "ZRJ7870728",
      first_name: "Pravin",
      middle_name: "Vaman",
      last_name: "Bansode",
      booth: @booth,
      village: @village,
      assembly: @assembly,
      sr_no: 1
    )
    @other = Voter.create!(
      voter_id: "ZRJ7870645",
      first_name: "Nilesh",
      middle_name: "Nanaso",
      last_name: "Bhalerao",
      booth: @booth,
      village: @village,
      assembly: @assembly,
      sr_no: 2
    )
  end

  teardown do
    ENV["SACPAD_ROLL_TOKEN"] = @previous_token
  end

  test "stores native names on the part and on voters found by voter id" do
    post native_names_path, params: payload, as: :json, headers: auth

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @assembly.id, body["assembly_id"]
    assert_equal "1", body["part"]
    assert_equal "Antarwali", body["village"]
    assert_equal 2, body["updated"]

    assert_equal "अंतरवली", @village.reload.native_name
    assert_equal "Antarwali", @village.name
    assert_equal "भूम", @taluka.reload.native_name
    assert_equal "उस्मानाबाद", @district.reload.native_name
    assert_equal "आंभी", @village.police_station_record.native_name
    assert_equal "Ambhi", @village.police_station

    @voter.reload
    assert_equal "प्रविण", @voter.native_first_name
    assert_equal "वामन", @voter.native_middle_name
    assert_equal "बनसोडे", @voter.native_last_name
    assert_equal "Pravin", @voter.first_name
    assert_equal "Vaman", @voter.middle_name
    assert_equal "Bansode", @voter.last_name
    assert_equal "निलेश", @other.reload.native_first_name
  end

  test "a missing voter rolls the native names back" do
    previous_village = @village.native_name
    previous_voter = @voter.native_first_name

    post native_names_path,
      params: payload.deep_merge(voters: [ { voter_id: "MISSING0001", native_first_name: "प्रविण" } ]),
      as: :json,
      headers: auth

    assert_response :unprocessable_entity
    assert_match "MISSING0001", JSON.parse(response.body)["error"]
    assert_equal previous_village, @village.reload.native_name
    assert_equal previous_voter, @voter.reload.native_first_name
  end

  test "rejects a missing token" do
    previous = @voter.native_first_name

    post native_names_path, params: payload, as: :json

    assert_response :unauthorized
    assert_equal previous, @voter.reload.native_first_name
  end

  test "rejects an unknown part" do
    post "/api/assemblies/#{@assembly.id}/parts/99/native_names",
      params: payload,
      as: :json,
      headers: auth

    assert_response :not_found
  end

  private

  def native_names_path
    "/api/assemblies/#{@assembly.id}/parts/1/native_names"
  end

  def auth
    { "Authorization" => "Bearer test-token" }
  end

  def payload
    {
      part_no: 1,
      taluka: { native_name: "भूम" },
      district: { native_name: "उस्मानाबाद" },
      village: { native_name: "अंतरवली" },
      police_station: { native_name: "आंभी" },
      voters: [
        {
          part_no: 1,
          serial: "1",
          voter_id: "ZRJ7870728",
          native_first_name: "प्रविण",
          native_middle_name: "वामन",
          native_last_name: "बनसोडे"
        },
        {
          part_no: 1,
          serial: "2",
          voter_id: "ZRJ7870645",
          native_first_name: "निलेश",
          native_middle_name: "नानासाहेब",
          native_last_name: "भालेराव"
        }
      ]
    }
  end
end
