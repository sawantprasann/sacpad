require "test_helper"

# Story 0.4 — the reusable Console catalog editor manages global reference data (Admin-only).
class ConsoleReferenceTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123", tier: :full)
  end

  test "reference catalogs require admin auth" do
    get "/console/states"
    assert_redirected_to new_admin_session_path
  end

  test "an admin can list and create reference rows via the shared editor" do
    sign_in @admin
    get "/console/states"
    assert_response :success

    assert_difference -> { State.count }, 1 do
      post "/console/states", params: { record: { name: "Maharashtra" } }
    end
    assert_redirected_to "/console/states"
  end

  test "the editor handles belongs_to fields (loksabha needs a state)" do
    sign_in @admin
    state = State.create!(name: "MH")
    assert_difference -> { Loksabha.count }, 1 do
      post "/console/loksabhas", params: { record: { state_id: state.id, name: "Baramati" } }
    end
  end
end
