require "test_helper"

# Story 3.5 — scoped Excel import for reports and mock poll.
class GroundReportsImportTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    state = State.create!(name: "Maharashtra")
    assembly = state.loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur")
    @village = assembly.villages.create!(name: "Nimgaon")
    @org.update!(constituency: assembly)

    @agency = Role.create!(name: "Agency", slug: "gr-agency", can_import: true)
    @agency.role_permissions.create!(module_name: "ground_reports", access_level: "write")
    @field = Role.create!(name: "Field", slug: "gr-field-import")
    @field.role_permissions.create!(module_name: "ground_reports", access_level: "write")
    @none = Role.create!(name: "Outsider", slug: "gr-import-none")

    @alice = User.create!(organization: @org, role: @agency, name: "Alice", email: "import-alice@example.com", password: "password123")
    @bob = User.create!(organization: @org, role: @field, name: "Bob", email: "import-bob@example.com", password: "password123")
    ActsAsTenant.with_tenant(@org) { Politician.create!(name: "Meera Patil", is_own_politician: true) }
  end

  test "an importer uploads a report sheet and a peer cannot see the report" do
    sign_in @alice
    get ground_reports_villages_path
    assert_select "a[href=?]", new_ground_reports_import_path, text: "Import"

    upload = workbook([
      [ "village", "issue", "resolution", "reported_at" ],
      [ "Nimgaon", "Water shortage", "Tanker", "2026-10-01" ],
      [ "Far", "Outside", nil, nil ]
    ])
    perform_enqueued_jobs do
      post ground_reports_imports_path, params: { import: { kind: "report", file: upload } }
    end
    import = GroundReports::Import.unscoped.order(:id).last
    assert_redirected_to ground_reports_import_path(import)
    follow_redirect!
    assert_match "Imported 1 report", @response.body
    assert_match "Row 3:", @response.body
    assert_equal @alice, ActsAsTenant.with_tenant(@org) { GroundReports::GroundReport.last.owner }

    sign_in @bob
    get ground_reports_village_path(@village)
    assert_no_match(/Water shortage/, @response.body)
    get ground_reports_villages_path
    assert_select "a[href=?]", new_ground_reports_import_path, count: 0
    post ground_reports_imports_path, params: { import: { kind: "report", file: upload } }
    assert_response :not_found
  end

  test "an importer uploads mock poll rows the organization can see" do
    sign_in @alice
    upload = workbook([
      %w[village politician respondent_name preference_basis vote_intent],
      [ "Nimgaon", "Meera Patil", "Asha", "individual", "yes" ]
    ])
    perform_enqueued_jobs do
      post ground_reports_imports_path, params: { import: { kind: "mock_poll", file: upload } }
    end
    follow_redirect!
    assert_match "Imported 1 response", @response.body

    sign_in @bob
    get ground_reports_village_path(@village)
    assert_match "Asha", @response.body
    assert_match "Likely to win: Meera Patil", @response.body
  end

  test "a writer can upload a mock poll sheet without the import capability" do
    sign_in @bob
    get ground_reports_village_path(@village)
    assert_select "a", text: "Upload"

    get new_ground_reports_import_path(kind: "mock_poll", village_id: @village.id)
    assert_response :success
    assert_match "Upload mock poll", @response.body

    upload = workbook([
      %w[village politician respondent_name preference_basis vote_intent],
      [ "Nimgaon", "Meera Patil", "Sheet Voter", "party", "yes" ]
    ])
    perform_enqueued_jobs do
      post ground_reports_imports_path, params: {
        village_id: @village.id,
        import: { kind: "mock_poll", file: upload }
      }
    end
    follow_redirect!
    assert_match "Imported 1 response", @response.body

    get new_ground_reports_import_path
    assert_response :not_found
  end

  test "a user without ground reports access cannot open the import" do
    outsider = User.create!(organization: @org, role: @none, name: "Out", email: "import-out@example.com", password: "password123")
    sign_in outsider
    get new_ground_reports_import_path
    assert_redirected_to root_path
  end

  private

  def workbook(rows)
    file = Tempfile.new([ "import", ".xlsx" ])
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Data") { |sheet| rows.each { |row| sheet.add_row row } }
    package.serialize(file.path)
    Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
  end
end
