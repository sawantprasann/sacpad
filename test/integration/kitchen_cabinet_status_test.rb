require "test_helper"

# Story 1.4 — status transitions over HTTP: write+subtree gated, logged, reflected on the detail.
class KitchenCabinetStatusTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @cat = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)

    @write = Role.create!(name: "Field", slug: "field")
    @write.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "write")
    @read = Role.create!(name: "Viewer", slug: "viewer")
    @read.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "read")

    @root  = User.create!(organization: @org, role: @write, name: "Root",  email: "root@example.com",  password: "password123")
    @alice = User.create!(organization: @org, role: @write, name: "Alice", email: "alice@example.com", password: "password123", parent: @root)
    @bob   = User.create!(organization: @org, role: @write, name: "Bob",   email: "bob@example.com",   password: "password123", parent: @root)
  end

  def ticket_for(owner)
    ActsAsTenant.with_tenant(@org) do
      KitchenCabinet::Ticket.create!(owner: owner, ticket_category: @cat, person_name: "P-#{owner.name}")
    end
  end

  test "a write owner advances status — a log row is written and the pill updates" do
    t = ticket_for(@alice)
    sign_in @alice
    assert_difference -> { KitchenCabinet::TicketStatusChange.unscoped.count }, 1 do
      patch status_kitchen_cabinet_ticket_path(t), params: { to_status: "in_progress" }
    end
    assert_redirected_to kitchen_cabinet_ticket_path(t)
    follow_redirect!
    assert_match "In progress", @response.body
  end

  test "an illegal transition is refused and writes no row" do
    t = ticket_for(@alice)
    sign_in @alice
    assert_no_difference -> { KitchenCabinet::TicketStatusChange.unscoped.count } do
      patch status_kitchen_cabinet_ticket_path(t), params: { to_status: "closed" }
    end
    assert t.reload.open?
  end

  test "a read-only user cannot change status (404)" do
    reader = User.create!(organization: @org, role: @read, name: "Reader", email: "reader@example.com", password: "password123", parent: @root)
    t = ticket_for(reader)
    sign_in reader
    patch status_kitchen_cabinet_ticket_path(t), params: { to_status: "in_progress" }
    assert_response :not_found
  end

  test "a ticket outside the viewer's subtree cannot be changed (404)" do
    t = ticket_for(@bob)
    sign_in @alice
    patch status_kitchen_cabinet_ticket_path(t), params: { to_status: "in_progress" }
    assert_response :not_found
  end
end
