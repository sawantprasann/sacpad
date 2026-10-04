require "test_helper"

class GeographyTest < ActiveSupport::TestCase
  test "hierarchy State -> Loksabha -> Assembly -> Village -> Booth" do
    state = State.create!(name: "Maharashtra")
    loksabha = state.loksabhas.create!(name: "Baramati")
    assembly = loksabha.assemblies.create!(name: "Indapur")
    village = assembly.villages.create!(name: "Nimgaon")
    booth = village.booths.create!(number: "B-12")

    assert_equal state, booth.village.assembly.loksabha.state
  end

  test "geography and parties are NOT tenant-scoped (global reference data)" do
    [ State, Loksabha, Assembly, Village, Booth, Party ].each do |klass|
      assert_not klass.ancestors.include?(OrganizationScoped), "#{klass} must be global, not tenant-scoped"
    end
  end

  test "deleting a state with dependents is blocked" do
    state = State.create!(name: "X")
    state.loksabhas.create!(name: "L")
    assert_not state.destroy
  end
end
