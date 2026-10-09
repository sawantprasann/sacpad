require "test_helper"

class ImportAssemblyVotersJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "a lok sabha sync queues a voter job for each assembly that has a part range" do
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: state, cd: "S1326")
    loksabha = Loksabha.create!(name: "Ahmednagar", state: state, district: district, constituency_no: "37")
    first = loksabha.assemblies.create!(name: "City", constituency_no: "255", first_part: 1, last_part: 2)
    second = loksabha.assemblies.create!(name: "Rural", constituency_no: "226", first_part: 1, last_part: 1)
    loksabha.assemblies.create!(name: "Bare", constituency_no: "227")

    assert_enqueued_jobs 2, only: ImportAssemblyVotersJob do
      assert_enqueued_with(job: ImportAssemblyVotersJob, args: [ first.id ]) do
        assert_enqueued_with(job: ImportAssemblyVotersJob, args: [ second.id ]) do
          ImportLoksabhaVotersJob.perform_now(loksabha.id)
        end
      end
    end
  end

  test "queues one job per part in the assembly range" do
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Satara", state: state, cd: "S1331")
    loksabha = Loksabha.create!(name: "Madha", state: state, district: district, constituency_no: "43")
    assembly = loksabha.assemblies.create!(name: "Phaltan (SC)", constituency_no: "255", first_part: 1, last_part: 3)

    assert_enqueued_with(job: ImportAssemblyPartJob, args: [ assembly.id, 1 ]) do
      assert_enqueued_with(job: ImportAssemblyPartJob, args: [ assembly.id, 3 ]) do
        assert_enqueued_jobs 3, only: ImportAssemblyPartJob do
          ImportAssemblyVotersJob.perform_now(assembly.id)
        end
      end
    end
  end
end
