require "test_helper"

class ImportAssemblyVotersJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "a lok sabha sync queues one voter job per assembly" do
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: state, cd: "S1326")
    loksabha = Loksabha.create!(name: "Ahmednagar", state: state, district: district, constituency_no: "37")
    first = loksabha.assemblies.create!(name: "City", constituency_no: "255")
    second = loksabha.assemblies.create!(name: "Rural", constituency_no: "226")

    assert_enqueued_with(job: ImportAssemblyVotersJob, args: [ first.id ]) do
      assert_enqueued_with(job: ImportAssemblyVotersJob, args: [ second.id ]) do
        ImportLoksabhaVotersJob.perform_now(loksabha.id)
      end
    end
  end
end
