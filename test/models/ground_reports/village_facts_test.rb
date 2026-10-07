require "test_helper"

class GroundReports::VillageFactsTest < ActiveSupport::TestCase
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @other = ActsAsTenant.without_tenant { Organization.create!(name: "Org B") }
    state = State.create!(name: "Maharashtra")
    assembly = state.loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur")
    @village = assembly.villages.create!(name: "Nimgaon")
    @outside = assembly.loksabha.assemblies.create!(name: "Elsewhere").villages.create!(name: "Far")
    @org.update!(constituency: assembly)
    @other.update!(constituency: assembly)
    @party = Party.create!(name: "Sample Party")
    @user = User.create!(
      organization: @org,
      role: Role.create!(name: "Field", slug: "facts-field"),
      name: "Rohan", email: "facts@example.com", password: "password123"
    )
  end

  test "a worship place accepts any type and rejects a village outside the constituency" do
    ActsAsTenant.with_tenant(@org) do
      place = GroundReports::WorshipPlace.new(village: @village, name: "Jama Masjid", place_type: "Mosque")
      assert place.save, place.errors.full_messages.to_sentence

      outside = GroundReports::WorshipPlace.new(village: @outside, name: "Shrine", place_type: "Temple")
      assert_not outside.save
      assert outside.errors[:village].any?
    end
  end

  test "a village has one yatra note per organization" do
    ActsAsTenant.with_tenant(@org) do
      assert GroundReports::VillageYatra.create!(village: @village, notes: "First walk", updated_by: @user)
      duplicate = GroundReports::VillageYatra.new(village: @village, notes: "Again")
      assert_not duplicate.save
    end

    ActsAsTenant.with_tenant(@other) do
      assert GroundReports::VillageYatra.create!(village: @village, notes: "Other org")
    end
    assert_equal 2, GroundReports::VillageYatra.unscoped.where(village: @village).count
  end

  test "opening a new current position closes the previous one" do
    ActsAsTenant.with_tenant(@org) do
      first = GroundReports::VillagePoliticalPosition.create!(
        village: @village, party: @party, representative_name: "Old", position_title: "Sarpanch",
        started_at: Date.new(2020, 1, 1)
      )
      second = GroundReports::VillagePoliticalPosition.create!(
        village: @village, party: @party, representative_name: "New", position_title: "Sarpanch",
        started_at: Date.new(2024, 6, 1)
      )

      assert_equal Date.new(2024, 6, 1), first.reload.ended_at
      assert_nil second.ended_at
      assert_equal [ second ], GroundReports::VillagePoliticalPosition.current.to_a
    end
  end
end
