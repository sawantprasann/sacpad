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
    [ State, Loksabha, Assembly, Village, Booth, PoliceStation, Party ].each do |klass|
      assert_not klass.ancestors.include?(OrganizationScoped), "#{klass} must be global, not tenant-scoped"
    end
  end

  test "booths are ordered by booth number" do
    village = State.create!(name: "Maharashtra").loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur").villages.create!(name: "Nimgaon")
    %w[10 2 B-12 1].each { |number| village.booths.create!(number: number) }

    assert_equal %w[1 2 10 B-12], village.booths.pluck(:number)
    assert_equal %w[1 2 10 B-12], Booth.by_number.where(village: village).pluck(:number)
  end

  test "deleting a state with dependents is blocked" do
    state = State.create!(name: "X")
    state.loksabhas.create!(name: "L")
    assert_not state.destroy
  end
end
