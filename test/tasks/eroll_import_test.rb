require "test_helper"
require "rake"

class ErollImportTaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("eroll:import")
    @task = Rake::Task["eroll:import"]
    @task.reenable
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: state, cd: "S1326")
    @loksabha = Loksabha.create!(name: "Ahmednagar", state: state, district: district, constituency_no: "37")
    @assembly = @loksabha.assemblies.create!(name: "Ahmednagar City", constituency_no: "255")
    @assembly.villages.create!(name: "Shindewadi").booths.create!(number: "1")
    @other = Loksabha.create!(name: "Other", state: state, district: district, constituency_no: "38")
  end

  test "queues a voter sync for an assembly" do
    assert_enqueued_with(job: ImportAssemblyVotersJob, args: [ @assembly.id ]) do
      @task.invoke(nil, @assembly.id.to_s)
    end
  end

  test "refuses an assembly that is not in the given Lok Sabha" do
    assert_no_enqueued_jobs only: ImportAssemblyVotersJob do
      assert_raises(SystemExit) { @task.invoke(@other.id.to_s, @assembly.id.to_s) }
    end
  end

  test "refuses an assembly that has no booths" do
    empty = @loksabha.assemblies.create!(name: "Empty", constituency_no: "226")

    assert_no_enqueued_jobs only: ImportAssemblyVotersJob do
      assert_raises(SystemExit) { @task.invoke(nil, empty.id.to_s) }
    end
  end
end
