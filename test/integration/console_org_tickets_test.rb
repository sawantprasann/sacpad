require "test_helper"

# Story 0.16 — org admin oversight: all Kitchen Cabinet tickets visible from org details page.
# Org-scoped (not subtree-scoped), with filtering and pagination.
class ConsoleOrgTicketsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    ActsAsTenant.without_tenant do
      @org_a = Organization.create!(name: "Org A")
      @org_b = Organization.create!(name: "Org B")
      @admin = Admin.create!(name: "Admin", email: "admin@example.com", password: "password123", tier: :full)

      @cat = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)
      @write = Role.create!(name: "Field", slug: "field")
      @write.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "write")

      @root_a = User.create!(organization: @org_a, role: @write, name: "Root A", email: "root_a@example.com", password: "password123")
      @alice = User.create!(organization: @org_a, role: @write, name: "Alice", email: "alice@example.com", password: "password123", parent: @root_a)
      @bob = User.create!(organization: @org_a, role: @write, name: "Bob", email: "bob@example.com", password: "password123", parent: @root_a)
      @root_b = User.create!(organization: @org_b, role: @write, name: "Root B", email: "root_b@example.com", password: "password123")

      ActsAsTenant.with_tenant(@org_a) do
        @ticket_alice_1 = KitchenCabinet::Ticket.create!(owner: @alice, ticket_category: @cat, person_name: "Alice's ticket 1")
        @ticket_alice_2 = KitchenCabinet::Ticket.create!(owner: @alice, ticket_category: @cat, person_name: "Alice's ticket 2", status: :in_progress)
        @ticket_bob = KitchenCabinet::Ticket.create!(owner: @bob, ticket_category: @cat, person_name: "Bob's ticket")
      end

      ActsAsTenant.with_tenant(@org_b) do
        KitchenCabinet::Ticket.create!(owner: @root_b, ticket_category: @cat, person_name: "Org B ticket")
      end
    end
  end

  test "org admin can view kitchen_cabinet tab" do
    sign_in @admin
    get console_organization_path(@org_a, tab: "kitchen_cabinet")
    assert_response :success
    assert_select "table tbody tr", 3
  end

  test "org admin can filter by status" do
    sign_in @admin
    get console_organization_path(@org_a, tab: "kitchen_cabinet", status: "in_progress")
    assert_response :success
    assert_select "table tbody tr", 1
  end

  test "org admin can search by person name" do
    sign_in @admin
    get console_organization_path(@org_a, tab: "kitchen_cabinet", q: "Bob")
    assert_response :success
    assert_select "table tbody tr", 1
  end

  test "org admin cannot see other org's tickets" do
    sign_in @admin
    get console_organization_path(@org_a, tab: "kitchen_cabinet")
    assert_response :success
    assert_select "table tbody tr", 3  # Only org A tickets
  end

  test "overview tab shows org metadata" do
    sign_in @admin
    get console_organization_path(@org_a, tab: "overview")
    assert_response :success
    assert_select "h1", text: @org_a.name
  end

  test "default tab is overview" do
    sign_in @admin
    get console_organization_path(@org_a)
    assert_response :success
    assert_select "h1", text: @org_a.name
    # Should show org metadata, not tickets
    assert_select "table tbody tr", 0
  end

  test "cadre tab shows placeholder" do
    sign_in @admin
    get console_organization_path(@org_a, tab: "cadre")
    assert_response :success
    assert_select "p", text: /Cadre Program/
  end

  test "unauthenticated cannot access org details" do
    get console_organization_path(@org_a, tab: "kitchen_cabinet")
    assert_redirected_to new_admin_session_path
  end
end
