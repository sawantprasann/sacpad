require "test_helper"

class BhashiniVillageVotersJobTest < ActiveSupport::TestCase
  setup do
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Osmanabad", state: state)
    loksabha = Loksabha.create!(name: "Osmanabad", state: state, district: district, native_locale: "mr")
    assembly = loksabha.assemblies.create!(name: "Paranda")
    taluka = district.talukas.create!(name: "Bhum")
    @village = assembly.villages.create!(name: "Antarwali", taluka: taluka)
    other = assembly.villages.create!(name: "Other", taluka: taluka)
    @voter = Voter.create!(
      voter_id: "ZRJ7870728",
      first_name: "Pravin",
      middle_name: "Vaman",
      last_name: "Bansode",
      village: @village,
      assembly: assembly,
      sr_no: 1
    )
    @outsider = Voter.create!(
      voter_id: "ZRJ0000001",
      first_name: "Asha",
      last_name: "Patil",
      village: other,
      assembly: assembly,
      sr_no: 1
    )
    @voter.update_columns(updated_at: 3.days.ago)
  end

  test "stores marathi parts for that village only" do
    outsider_name = @outsider.native_first_name
    singleton = BhashiniVillageVotersJob.singleton_class
    singleton.alias_method :__original_translate, :translate
    singleton.define_method(:translate) do |names|
      names.map { |name| { "source" => name, "target" => "प्रविण वामन बनसोडे" } }
    end
    BhashiniVillageVotersJob.perform_now(@village.id)
  ensure
    singleton.alias_method :translate, :__original_translate if singleton

    @voter.reload
    assert_equal "प्रविण", @voter.native_first_name
    assert_equal "वामन", @voter.native_middle_name
    assert_equal "बनसोडे", @voter.native_last_name
    assert_equal "Pravin", @voter.first_name
    assert_equal outsider_name, @outsider.reload.native_first_name
  end

  test "skips voters updated yesterday or today" do
    recent = Voter.create!(
      voter_id: "ZRJ7870729",
      first_name: "Recent",
      last_name: "Patil",
      village: @village,
      assembly: @voter.assembly,
      sr_no: 2
    )
    recent_native = recent.native_first_name
    sent = []
    singleton = BhashiniVillageVotersJob.singleton_class
    singleton.alias_method :__original_translate, :translate
    singleton.define_method(:translate) do |names|
      sent.concat(names)
      names.map { |name| { "source" => name, "target" => "प्रविण वामन बनसोडे" } }
    end

    BhashiniVillageVotersJob.perform_now(@village.id)

    assert_equal [ "Pravin Vaman Bansode" ], sent
    assert_equal recent_native, recent.reload.native_first_name
  ensure
    singleton.alias_method :translate, :__original_translate if defined?(singleton) && singleton
  end
end
