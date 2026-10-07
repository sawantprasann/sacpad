require "test_helper"

# Story 1.1 — categories drive the Kitchen Cabinet sidebar submenu + ?category= filter, gated on
# the viewer's Kitchen Cabinet module permission (enforced in the controller, not UI-only).
class KitchenCabinetNavTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @water  = TicketCategory.create!(name: "Water", slug: "water", display_order: 1, active: true)
    @hidden = TicketCategory.create!(name: "Archived", slug: "archived", display_order: 2, active: false)
  end

  def user_with_kc_access
    role = Role.create!(name: "Field", slug: "field")
    role.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "write")
    User.create!(organization: @org, role: role, name: "Rohan",
                 email: "rohan@example.com", password: "password123")
  end

  def user_without_kc_access
    role = Role.create!(name: "No Access", slug: "no_access")
    User.create!(organization: @org, role: role, name: "Nisha",
                 email: "nisha@example.com", password: "password123")
  end

  test "a KC-permitted user sees the category submenu with active categories only" do
    sign_in user_with_kc_access
    get root_path
    assert_response :success
    assert_match "Kitchen Cabinet", @response.body
    assert_match "Water", @response.body
    assert_no_match(/Archived/, @response.body)
    assert_match kitchen_cabinet_tickets_path(category: "water"), @response.body
  end

  test "a user without KC access sees no Kitchen Cabinet nav entry" do
    sign_in user_without_kc_access
    get root_path
    assert_response :success
    assert_no_match(/Kitchen Cabinet/, @response.body)
  end

  test "the stub list honors the category filter for a permitted user" do
    sign_in user_with_kc_access
    get kitchen_cabinet_tickets_path(category: "water")
    assert_response :success
    assert_match "Water", @response.body
    assert_select "a[href=?]", new_kitchen_cabinet_ticket_path(category: "water")
  end

  test "a user without KC access cannot reach the module by URL" do
    sign_in user_without_kc_access
    get kitchen_cabinet_tickets_path(category: "water")
    assert_redirected_to root_path
  end
end
