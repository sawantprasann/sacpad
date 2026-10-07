require "test_helper"
require "roo"

# Story 2.3 — recent cadre activity widget (FR26/FR50) and viewer-scoped Excel export (FR49).
class CadreProgramFeedTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @write = Role.create!(name: "Field Cadre", slug: "field-cadre-feed")
    @write.role_permissions.create!(module_name: "cadre_program", access_level: "write")
    @none = Role.create!(name: "No Cadre Feed", slug: "no-cadre-feed")
    @root  = User.create!(organization: @org, role: @write, name: "Root",  email: "feed-root@example.com",  password: "password123")
    @alice = User.create!(organization: @org, role: @write, name: "Alice", email: "feed-alice@example.com", password: "password123", parent: @root)
    @bob   = User.create!(organization: @org, role: @write, name: "Bob",   email: "feed-bob@example.com",   password: "password123", parent: @root)
  end

  def make_activity(owner:, category: :program_by_party, notes: "Warm reaction")
    ActsAsTenant.with_tenant(@org) do
      CadreProgram::CadreActivity.create!(
        owner: owner, category: category, impact_notes: notes,
        program_attributes: { program_name: "Booth meeting" }
      )
    end
  end

  def xlsx_cells
    file = Tempfile.new([ "export", ".xlsx" ])
    file.binmode
    file.write(@response.body)
    file.rewind
    Roo::Excelx.new(file.path).sheet(0).to_a.flatten.map(&:to_s)
  ensure
    file&.close
  end

  test "a permitted user sees their own recent activity and not a peer's" do
    make_activity(owner: @alice, notes: "Alice rally")
    make_activity(owner: @bob, notes: "Bob lane")
    sign_in @alice
    get root_path
    assert_response :success
    assert_match "Recent cadre activity", @response.body
    assert_match "Alice rally", @response.body
    assert_no_match(/Bob lane/, @response.body)
  end

  test "a user without cadre access does not see the widget" do
    outsider = User.create!(organization: @org, role: @none, name: "Nope", email: "feed-nope@example.com", password: "password123")
    sign_in outsider
    get root_path
    assert_response :success
    assert_no_match(/Recent cadre activity/, @response.body)
  end

  test "the export is scoped to the viewer's subtree" do
    make_activity(owner: @alice, notes: "Alice rally")
    make_activity(owner: @bob, notes: "Bob lane")
    sign_in @alice
    get cadre_program_activities_path(format: :xlsx)
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", @response.media_type
    assert_match(/cadre_program_activities\.xlsx/, @response.headers["Content-Disposition"])

    cells = xlsx_cells
    assert_includes cells, "Alice rally"
    assert_not_includes cells, "Bob lane"
  end

  test "the export respects the category filter" do
    make_activity(owner: @alice, category: :program_by_party, notes: "Party rally")
    ActsAsTenant.with_tenant(@org) do
      CadreProgram::CadreActivity.create!(
        owner: @alice, category: :leadership_meets, impact_notes: "Met the sarpanch",
        leadership_meet_attributes: { whom_to_meet: "Sarpanch" }
      )
    end
    sign_in @alice
    get cadre_program_activities_path(format: :xlsx, category: "leadership_meets")
    assert_response :success

    cells = xlsx_cells
    assert_includes cells, "Met the sarpanch"
    assert_includes cells, "Leadership Meets"
    assert_not_includes cells, "Party rally"
  end

  test "the list shows the selected category and an excel link for the same filter" do
    make_activity(owner: @alice, notes: "Alice rally")
    sign_in @alice
    get cadre_program_activities_path(category: "program_by_party")
    assert_response :success
    assert_match "Program By Party", @response.body
    assert_select "a[href=?]", cadre_program_activities_path(format: :xlsx, category: "program_by_party")
  end

  test "a user without cadre access cannot export" do
    outsider = User.create!(organization: @org, role: @none, name: "Nope", email: "feed-nope-xlsx@example.com", password: "password123")
    sign_in outsider
    get cadre_program_activities_path(format: :xlsx)
    assert_redirected_to root_path
  end
end
