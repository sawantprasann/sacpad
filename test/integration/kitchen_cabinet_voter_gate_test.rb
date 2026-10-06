require "test_helper"

# Story 1.6 — the voter-ID gate over HTTP: locked until closed, write ∩ subtree gated.
class KitchenCabinetVoterGateTest < ActionDispatch::IntegrationTest
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

  def ticket_for(owner, closed: false)
    ActsAsTenant.with_tenant(@org) do
      t = KitchenCabinet::Ticket.create!(owner: owner, ticket_category: @cat, person_name: "P-#{owner.name}")
      if closed
        t.change_status!(to: "in_progress", actor: owner)
        t.change_status!(to: "closed", actor: owner)
      end
      t
    end
  end

  test "voter_id can be saved on a closed ticket" do
    t = ticket_for(@alice, closed: true)
    sign_in @alice
    patch voter_kitchen_cabinet_ticket_path(t), params: { voter_id: "VTR123" }
    assert_redirected_to kitchen_cabinet_ticket_path(t)
    assert_equal "VTR123", t.reload.voter_id
  end

  test "voter_id is rejected on an open ticket (not persisted)" do
    t = ticket_for(@alice)
    sign_in @alice
    patch voter_kitchen_cabinet_ticket_path(t), params: { voter_id: "VTR123" }
    assert_nil t.reload.voter_id
  end

  test "the gate field is locked on an open ticket and editable once closed" do
    sign_in @alice

    open_ticket = ticket_for(@alice)
    get kitchen_cabinet_ticket_path(open_ticket)
    assert_match "Voter ID unlocks once this issue is closed", @response.body
    assert_match "disabled", @response.body

    closed_ticket = ticket_for(@alice, closed: true)
    get kitchen_cabinet_ticket_path(closed_ticket)
    assert_match voter_kitchen_cabinet_ticket_path(closed_ticket), @response.body
  end

  test "a read-only user cannot set voter_id (404)" do
    reader = User.create!(organization: @org, role: @read, name: "Reader", email: "reader@example.com", password: "password123", parent: @root)
    t = ticket_for(reader, closed: true)
    sign_in reader
    patch voter_kitchen_cabinet_ticket_path(t), params: { voter_id: "VTR1" }
    assert_response :not_found
  end

  test "an out-of-subtree ticket cannot have voter_id set (404)" do
    t = ticket_for(@bob, closed: true)
    sign_in @alice
    patch voter_kitchen_cabinet_ticket_path(t), params: { voter_id: "VTR1" }
    assert_response :not_found
  end
end
