require "test_helper"

# Story 1.8 — the KC "open tickets by status" dashboard widget: gated by module permission,
# scoped to the viewer's subtree (reuses the framework from Story 0.14).
class KitchenCabinetDashboardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @cat = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)
    @write = Role.create!(name: "Field", slug: "field")
    @write.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "write")
    @none = Role.create!(name: "Outsider", slug: "outsider") # no kitchen_cabinet permission
    @alice = User.create!(organization: @org, role: @write, name: "Alice", email: "alice@example.com", password: "password123")
  end

  test "a KC-permitted user sees the Open tickets by status widget" do
    ActsAsTenant.with_tenant(@org) do
      KitchenCabinet::Ticket.create!(owner: @alice, ticket_category: @cat, person_name: "Asha")
    end
    sign_in @alice
    get root_path
    assert_response :success
    assert_match "Open tickets by status", @response.body
  end

  test "a user without KC access does not see the widget" do
    outsider = User.create!(organization: @org, role: @none, name: "Nope", email: "nope@example.com", password: "password123")
    sign_in outsider
    get root_path
    assert_response :success
    assert_no_match(/Open tickets by status/, @response.body)
  end
end
