require "test_helper"

class ConsoleAssemblySyncTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123", tier: :full)
    state = State.create!(name: "Maharashtra", cd: "S13")
    district = District.create!(name: "Ahmednagar", state: state, cd: "S1326")
    loksabha = Loksabha.create!(name: "Ahmednagar", state: state, district: district, constituency_no: "37")
    @assembly = loksabha.assemblies.create!(name: "Ahmednagar City", constituency_no: "255")
    village = @assembly.villages.create!(name: "Shindewadi")
    village.booths.create!(number: "1")
  end

  test "the assembly list has a sync button on each row" do
    sign_in @admin
    get "/console/assemblies"
    assert_response :success
    assert_select "button", text: "Sync"
  end

  test "sync queues a background job for that assembly" do
    sign_in @admin

    assert_enqueued_with(job: ImportAssemblyVotersJob, args: [ @assembly.id ]) do
      post sync_voters_console_assembly_path(@assembly)
    end

    assert_redirected_to "/console/assemblies"
    follow_redirect!
    assert_match "Voter sync started for Ahmednagar City", response.body
  end

  test "sync explains when the assembly has no booths" do
    sign_in @admin
    empty = @assembly.loksabha.assemblies.create!(name: "Empty", constituency_no: "226")

    assert_no_enqueued_jobs only: ImportAssemblyVotersJob do
      post sync_voters_console_assembly_path(empty)
    end

    assert_redirected_to "/console/assemblies"
    follow_redirect!
    assert_match "no booths", response.body
  end
end
