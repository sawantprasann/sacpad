require "test_helper"

# Ground Reports dashboard widget: recent work inline for the viewer's constituency.
class GroundReportsDashboardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    state = State.create!(name: "Maharashtra")
    loksabha = state.loksabhas.create!(name: "Baramati")
    assembly = loksabha.assemblies.create!(name: "Indapur")
    @village = assembly.villages.create!(name: "Nimgaon")
    @org.update!(constituency: assembly)

    @write = Role.create!(name: "Field", slug: "gr-dash-write")
    @write.role_permissions.create!(module_name: "ground_reports", access_level: "read")
    @none = Role.create!(name: "Outsider", slug: "gr-dash-none")
    @alice = User.create!(organization: @org, role: @write, name: "Alice", email: "gr-dash@example.com", password: "password123")
  end

  test "a permitted user sees recent work inline and not another org's or a discarded row" do
    ActsAsTenant.with_tenant(@org) do
      GroundReports::VillageWork.create!(
        village: @village, title: "Canal lining", concern_person: "Gram Sevak",
        nidhi_asked: 150000, nidhi_category: :mla_fund, status: :in_progress
      )
      discarded = GroundReports::VillageWork.create!(
        village: @village, title: "Old well", concern_person: "Sarpanch",
        nidhi_asked: 500, nidhi_category: :dpdc, status: :not_started
      )
      discarded.discard
    end
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Org B", constituency: @org.constituency) }
    ActsAsTenant.with_tenant(other) do
      GroundReports::VillageWork.create!(
        village: @village, title: "Hidden canal", concern_person: "Other",
        nidhi_asked: 999999, nidhi_category: :other, nidhi_category_name: "Special", status: :not_started
      )
    end

    sign_in @alice
    get root_path
    assert_response :success
    assert_match "Recent ground reports", @response.body
    assert_match "Canal lining", @response.body
    assert_match "Nimgaon", @response.body
    assert_match "150,000", @response.body
    assert_match "MLA fund", @response.body
    assert_match "In progress", @response.body
    assert_no_match(/Old well/, @response.body)
    assert_no_match(/Hidden canal/, @response.body)
  end

  test "a user without ground reports access does not see the widget" do
    outsider = User.create!(organization: @org, role: @none, name: "Nope", email: "gr-dash-nope@example.com", password: "password123")
    sign_in outsider
    get root_path
    assert_response :success
    assert_no_match(/Recent ground reports/, @response.body)
  end
end
