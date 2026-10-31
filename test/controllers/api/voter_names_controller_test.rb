require "test_helper"

class Api::VoterNamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["SACPAD_ROLL_TOKEN"]
    ENV["SACPAD_ROLL_TOKEN"] = "test-token"
    state = State.create!(name: "Maharashtra", cd: "S13")
    @district = District.create!(name: "Osmanabad", state: state)
    loksabha = Loksabha.create!(name: "Osmanabad", state: state, district: @district, native_locale: "mr")
    assembly = loksabha.assemblies.create!(name: "Paranda")
    taluka = @district.talukas.create!(name: "Bhum")
    @village = assembly.villages.create!(name: "Antarwali", taluka: taluka)
    other_village = assembly.villages.create!(name: "Other", taluka: taluka)
    @voter = Voter.create!(
      voter_id: "ZRJ7870728",
      first_name: "Pravin",
      middle_name: "Vaman",
      last_name: "Bansode",
      village: @village,
      assembly: assembly,
      sr_no: 1
    )
    @filled = Voter.create!(
      voter_id: "ZRJ7870645",
      first_name: "Nilesh",
      middle_name: "Nanaso",
      last_name: "Bhalerao",
      native_first_name: "निलेश",
      village: @village,
      assembly: assembly,
      sr_no: 2
    )
    @outsider = Voter.create!(
      voter_id: "ZRJ0000001",
      first_name: "Asha",
      last_name: "Patil",
      village: other_village,
      assembly: assembly,
      sr_no: 1
    )
    @voter.update_columns(native_first_name: nil)
    @outsider_native_name = @outsider.native_first_name
  end

  teardown do
    ENV["SACPAD_ROLL_TOKEN"] = @previous_token
  end

  test "lists villages in the district" do
    get "/api/districts/#{@district.id}/villages", headers: auth

    assert_response :ok
    names = JSON.parse(response.body)["villages"].map { |village| village["name"] }
    assert_includes names, "Antarwali"
    assert_includes names, "Other"
  end

  test "returns english voter names for one village" do
    get "/api/villages/#{@village.id}/voter_names", headers: auth

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @village.id, body["village_id"]
    ids = body["voters"].map { |voter| voter["id"] }
    assert_includes ids, @voter.id
    assert_not_includes ids, @outsider.id
    row = body["voters"].find { |voter| voter["id"] == @voter.id }
    assert_equal "Pravin", row["first_name"]
    assert_equal "Vaman", row["middle_name"]
    assert_equal "Bansode", row["last_name"]
  end

  test "missing=1 skips voters that already have a native first name" do
    get "/api/villages/#{@village.id}/voter_names?missing=1", headers: auth

    ids = JSON.parse(response.body)["voters"].map { |voter| voter["id"] }
    assert_includes ids, @voter.id
    assert_not_includes ids, @filled.id
  end

  test "stores native names for voters in that village" do
    post "/api/villages/#{@village.id}/voter_names",
      params: {
        voters: [
          {
            id: @voter.id,
            native_first_name: "प्रविण",
            native_middle_name: "वामन",
            native_last_name: "बनसोडे"
          },
          { id: @outsider.id, native_first_name: "आशा" }
        ]
      },
      as: :json,
      headers: auth

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body["updated"]
    assert_includes body["missing"], @outsider.id

    @voter.reload
    assert_equal "प्रविण", @voter.native_first_name
    assert_equal "वामन", @voter.native_middle_name
    assert_equal "बनसोडे", @voter.native_last_name
    assert_equal "Pravin", @voter.first_name
    assert_equal @outsider_native_name, @outsider.reload.native_first_name
  end

  test "rejects a missing token" do
    get "/api/villages/#{@village.id}/voter_names"

    assert_response :unauthorized
  end

  private

  def auth
    { "Authorization" => "Bearer test-token" }
  end
end
