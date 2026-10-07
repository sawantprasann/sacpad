require "test_helper"

class Imports::GroundReportsImporterTest < ActiveSupport::TestCase
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    state = State.create!(name: "Maharashtra")
    assembly = state.loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur")
    @village = assembly.villages.create!(name: "Nimgaon")
    assembly.loksabha.assemblies.create!(name: "Elsewhere").villages.create!(name: "Far")
    @org.update!(constituency: assembly)
    role = Role.create!(name: "Agency", slug: "import-agency", can_import: true)
    role.role_permissions.create!(module_name: "ground_reports", access_level: "write")
    @user = User.create!(organization: @org, role: role, name: "Asha", email: "import-asha@example.com", password: "password123")
    @politician = ActsAsTenant.with_tenant(@org) { Politician.create!(name: "Meera Patil", is_own_politician: true) }
  end

  test "a mixed report sheet keeps the good row and records the bad ones" do
    result = import(:report, [
      [ "Village", "Issue", "Resolution", "Reported at", "organization" ],
      [ "Nimgaon", "Water shortage", "Tanker", "2026-10-01", "999" ],
      [ "Far", "Outside village", nil, nil, nil ],
      [ "Nimgaon", nil, nil, nil, nil ]
    ])

    assert_equal 1, result.imported_count
    assert_equal [ 3, 4 ], result.row_errors.map { |error| error["row"] }
    ActsAsTenant.with_tenant(@org) do
      report = GroundReports::GroundReport.last
      assert_equal "Water shortage", report.issue_text
      assert_equal @user, report.owner
      assert_equal @org, report.organization
      assert_equal Date.new(2026, 10, 1), report.reported_at
    end
  end

  test "a mixed mock poll sheet keeps the good rows" do
    result = import(:mock_poll, [
      %w[village politician respondent_name respondent_mobile preference_basis vote_intent note],
      [ "Nimgaon", "Meera Patil", "Asha", "9876543210", "individual", "yes", "Knows her" ],
      [ "Nimgaon", "Nobody", "Ramesh", nil, "party", "no", nil ],
      [ "Nimgaon", "Meera Patil", "Lata", nil, "individual", "undecided", nil ]
    ])

    assert_equal 2, result.imported_count
    assert_equal [ 3 ], result.row_errors.map { |error| error["row"] }
    ActsAsTenant.with_tenant(@org) do
      undecided = GroundReports::MockPollResponse.find_by!(respondent_name: "Lata")
      assert_nil undecided.vote_intent
      assert_equal @user, undecided.created_by
    end
  end

  test "a file that is not a workbook imports nothing" do
    result = nil
    ActsAsTenant.with_tenant(@org) do
      import = GroundReports::Import.new(user: @user, kind: :report)
      import.organization = @org
      import.file.attach(io: StringIO.new("not excel"), filename: "notes.xlsx", content_type: "application/octet-stream")
      import.save!
      result = Imports::GroundReportImporter.new(import).call
    end
    assert_equal 0, result.imported_count
    assert_equal "The file could not be read as an Excel workbook", result.row_errors.first["message"]
  end

  private

  def import(kind, rows)
    file = Tempfile.new([ "import", ".xlsx" ])
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Data") { |sheet| rows.each { |row| sheet.add_row row } }
    package.serialize(file.path)

    ActsAsTenant.with_tenant(@org) do
      record = GroundReports::Import.new(user: @user, kind: kind)
      record.organization = @org
      record.file.attach(io: File.open(file.path), filename: "import.xlsx",
                         content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      record.save!
      importer = kind == :report ? Imports::GroundReportImporter : Imports::MockPollImporter
      importer.new(record).call
    end
  ensure
    file.close!
  end
end
