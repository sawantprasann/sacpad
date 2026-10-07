require "test_helper"

# Story 2.1 — Cadre Program is a real sidebar entry for permitted roles, and unreachable otherwise.
class CadreProgramNavTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
  end

  def user_with_access
    role = Role.create!(name: "Cadre Nav", slug: "cadre-nav")
    role.role_permissions.create!(module_name: "cadre_program", access_level: "write")
    User.create!(organization: @org, role: role, name: "Rohan",
                 email: "cadre-nav@example.com", password: "password123")
  end

  def user_without_access
    role = Role.create!(name: "No Cadre", slug: "no-cadre")
    User.create!(organization: @org, role: role, name: "Nisha",
                 email: "no-cadre@example.com", password: "password123")
  end

  test "a permitted user sees Cadre Program categories as a submenu" do
    sign_in user_with_access
    get root_path
    assert_response :success
    assert_match "Cadre Program", @response.body
    assert_select "button", text: /Cadre Program/
    CadreProgram::CadreActivity::CATEGORY_LABELS.each do |key, label|
      assert_select "a[href=?]", cadre_program_activities_path(category: key), text: label
    end
    assert_select ".menu-dropdown-badge", text: "soon", count: 3
    assert_no_match(/Ground Reports/, @response.body)
    assert_match "RAG Mapping", @response.body
  end

  test "a category submenu link filters the list and pre-fills a new activity" do
    sign_in user_with_access
    get cadre_program_activities_path(category: "leadership_meets")
    assert_response :success
    assert_match "Leadership Meets", @response.body
    assert_select "table"
    assert_select "a.menu-dropdown-item-active", text: "Leadership Meets"
    assert_select "a[href=?]", new_cadre_program_activity_path(category: "leadership_meets")

    get new_cadre_program_activity_path(category: "leadership_meets")
    assert_response :success
    assert_select "div.max-w-xl", count: 0
    assert_select "select[name=?] option[selected][value=?]", "cadre_activity[category]", "leadership_meets"
    assert_select "h1", text: "Create Leadership Meets"
    assert_select "button[type=submit]", text: "Create Leadership Meets"
  end

  test "a user without access sees no Cadre Program entry and cannot open the module" do
    sign_in user_without_access
    get root_path
    assert_response :success
    assert_select "a[href=?]", cadre_program_activities_path, count: 0
    assert_no_match(/Cadre Program/, @response.body)
    assert_no_match(/Ground Reports/, @response.body)

    get cadre_program_activities_path
    assert_redirected_to root_path
  end
end
