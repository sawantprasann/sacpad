require "test_helper"

class GroundReports::VillageContactsTest < ActiveSupport::TestCase
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    state = State.create!(name: "Maharashtra")
    assembly = state.loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur")
    @village = assembly.villages.create!(name: "Nimgaon")
    @outside = assembly.loksabha.assemblies.create!(name: "Elsewhere").villages.create!(name: "Far")
    @org.update!(constituency: assembly)
  end

  test "karyakartas and admin contacts are not users" do
    assert_not_includes GroundReports::VillageLocalKaryakarta.column_names, "user_id"
    assert_not_includes GroundReports::VillageLocalAdminContact.column_names, "user_id"

    ActsAsTenant.with_tenant(@org) do
      assert_no_difference -> { User.count } do
        karyakarta = GroundReports::VillageLocalKaryakarta.create!(
          village: @village, name: "Asha", phone: "9876543210", notes: "Booth 3"
        )
        contact = GroundReports::VillageLocalAdminContact.create!(
          village: @village, name: "Ramesh", role_title: "Gram Sevak", phone: "9123456780"
        )
        assert_equal "Asha", karyakarta.name
        assert_equal "Gram Sevak", contact.role_title
      end

      outside = GroundReports::VillageLocalKaryakarta.new(village: @outside, name: "Far worker")
      assert_not outside.save
      assert outside.errors[:village].any?
    end
  end
end
