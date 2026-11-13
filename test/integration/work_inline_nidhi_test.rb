require "test_helper"
require "roo"

class WorkInlineNidhiTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    state = State.create!(name: "Maharashtra")
    assembly = state.loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur")
    @nimgaon = assembly.villages.create!(name: "Nimgaon")
    @kalas = assembly.villages.create!(name: "Kalas")
    @org.update!(constituency: assembly)

    role = Role.create!(name: "Field", slug: "work-nidhi")
    role.role_permissions.create!(module_name: "ground_reports", access_level: "read")
    @user = User.create!(organization: @org, role: role, name: "Mina", email: "work-nidhi@example.com", password: "password123")

    ActsAsTenant.with_tenant(@org) do
      @canal = GroundReports::VillageWork.create!(
        village: @nimgaon, title: "Canal lining", concern_person: "Gram Sevak",
        nidhi_asked: 150_000, nidhi_category: :mla_fund, status: :in_progress
      )
      @road = GroundReports::VillageWork.create!(
        village: @kalas, title: "Road repair", concern_person: "Sarpanch",
        nidhi_asked: 40_000, nidhi_category: :dpdc, status: :completed
      )
      discarded = GroundReports::VillageWork.create!(
        village: @nimgaon, title: "Old well", concern_person: "Sarpanch",
        nidhi_asked: 500, nidhi_category: :dpdc, status: :not_started
      )
      discarded.discard
    end
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Org B", constituency: assembly) }
    ActsAsTenant.with_tenant(other) do
      GroundReports::VillageWork.create!(
        village: @nimgaon, title: "Hidden canal", concern_person: "Other",
        nidhi_asked: 999_999, nidhi_category: :other, nidhi_category_name: "Special", status: :not_started
      )
    end
    sign_in @user
  end

  test "the dashboard charts nidhi by work status" do
    get root_path

    assert_response :success
    assert_match "Nidhi by work status", response.body
    assert_select "#dashboard-work-nidhi"
    assert_select "a[href=?]", ground_reports_work_inlines_path, text: "View work"
    assert_match "150,000", response.body
    assert_match "40,000", response.body
    assert_no_match(/Old well/, response.body)
    assert_no_match(/Hidden canal/, response.body)
  end

  test "ground reports links to the work list above the village filters" do
    get ground_reports_villages_path

    assert_response :success
    assert_select "a[href=?]", ground_reports_work_inlines_path, text: /All work inline/ do
      assert_select "svg"
    end
    assert_no_match(/999,999/, response.body)
  end

  test "the work list splits nidhi by status and filters by status and village name" do
    get ground_reports_work_inlines_path

    assert_response :success
    assert_match "Canal lining", response.body
    assert_match "Road repair", response.body
    assert_match "190,000", response.body
    assert_select "a[href=?]", ground_reports_work_inlines_path(format: :xlsx)
    assert_select "[data-controller=min-search-select] select[name=village]" do
      assert_select "option", text: "Nimgaon"
      assert_select "option", text: "Kalas"
    end

    get ground_reports_work_inlines_path(status: "completed", village: "Kalas")
    assert_match "Road repair", response.body
    assert_no_match(/Canal lining/, response.body)
    assert_match "40,000", response.body
  end

  test "the excel export keeps the filters and totals the nidhi asked" do
    get ground_reports_work_inlines_path(format: :xlsx, village: "Nimgaon")

    assert_response :success
    sheet = workbook.sheet(0)
    assert_equal "Nidhi asked", sheet.cell(1, 4)
    assert_equal [ "Canal lining" ], (2..(sheet.last_row - 1)).map { |row| sheet.cell(row, 2) }
    assert_equal "Total", sheet.cell(sheet.last_row, 3)
    assert_in_delta 150_000, sheet.cell(sheet.last_row, 4).to_f, 0.01
  end

  private

  def workbook
    file = Tempfile.new([ "works", ".xlsx" ])
    file.binmode
    file.write(response.body)
    file.close
    Roo::Spreadsheet.open(file.path, extension: :xlsx)
  end
end
