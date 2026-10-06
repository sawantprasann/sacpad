require "test_helper"

# Story 1.3 — scoped, filtered, paginated browse list + ticket detail. Scope = org ∩ viewer
# subtree ∩ kept; out-of-scope tickets 404.
class KitchenCabinetBrowseTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @water = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)
    @road  = TicketCategory.create!(name: "Road & Transport", slug: "road", display_order: 2)

    @write = Role.create!(name: "Field", slug: "field")
    @write.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "write")
    @read = Role.create!(name: "Viewer", slug: "viewer")
    @read.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "read")
    @none = Role.create!(name: "Outsider", slug: "outsider") # no kitchen_cabinet permission

    @root  = User.create!(organization: @org, role: @write, name: "Root",  email: "root@example.com",  password: "password123")
    @alice = User.create!(organization: @org, role: @write, name: "Alice", email: "alice@example.com", password: "password123", parent: @root)
    @bob   = User.create!(organization: @org, role: @write, name: "Bob",   email: "bob@example.com",   password: "password123", parent: @root)
  end

  def make_ticket(owner:, category: @water, org: @org, status: :open, person: nil)
    ActsAsTenant.with_tenant(org) do
      KitchenCabinet::Ticket.create!(owner: owner, ticket_category: category, status: status,
                                     person_name: person || "By-#{owner.name}", village: "Wadi")
    end
  end

  test "the list shows only tickets owned within the viewer's subtree" do
    mine  = make_ticket(owner: @alice, person: "Mine Asha")
    peers = make_ticket(owner: @bob,   person: "Peer Bimal")
    sign_in @alice
    get kitchen_cabinet_tickets_path
    assert_response :success
    assert_match "Mine Asha", @response.body
    assert_no_match(/Peer Bimal/, @response.body)
    assert_match kitchen_cabinet_ticket_path(mine), @response.body
    assert_not_includes @response.body, kitchen_cabinet_ticket_path(peers)
  end

  test "category and status filters narrow the list" do
    make_ticket(owner: @alice, category: @water, person: "Water One")
    make_ticket(owner: @alice, category: @road,  person: "Road One")
    make_ticket(owner: @alice, category: @water, status: :closed, person: "Water Closed")

    sign_in @alice
    get kitchen_cabinet_tickets_path(category: "water")
    assert_match "Water One", @response.body
    assert_no_match(/Road One/, @response.body)

    get kitchen_cabinet_tickets_path(category: "water", status: "closed")
    assert_match "Water Closed", @response.body
    assert_no_match(/Water One/, @response.body)
  end

  test "the list is paginated (Get All Details never dumps the raw table)" do
    25.times { |i| make_ticket(owner: @alice, person: "Grievance #{i}") }
    sign_in @alice
    get kitchen_cabinet_tickets_path
    assert_response :success
    assert_match "Page 1 of 2", @response.body
    get kitchen_cabinet_tickets_path(page: 2)
    assert_match "Page 2 of 2", @response.body
  end

  test "soft-deleted tickets are excluded" do
    t = make_ticket(owner: @alice, person: "Discarded Dinesh")
    t.discard
    sign_in @alice
    get kitchen_cabinet_tickets_path
    assert_no_match(/Discarded Dinesh/, @response.body)
  end

  test "opening an in-subtree ticket renders its detail" do
    t = make_ticket(owner: @alice, person: "Asha", category: @water)
    sign_in @alice
    get kitchen_cabinet_ticket_path(t)
    assert_response :success
    assert_match "Asha", @response.body
    assert_match t.ticket_number, @response.body
  end

  test "opening a ticket outside the viewer's subtree returns 404" do
    t = make_ticket(owner: @bob, person: "Bimal")
    sign_in @alice
    get kitchen_cabinet_ticket_path(t)
    assert_response :not_found
  end

  test "opening another org's ticket returns 404" do
    other_org = ActsAsTenant.without_tenant { Organization.create!(name: "Org B") }
    other_user = ActsAsTenant.without_tenant do
      User.create!(organization: other_org, role: @write, name: "Zed", email: "zed@example.com", password: "password123")
    end
    foreign = make_ticket(owner: other_user, org: other_org, person: "Foreign")
    sign_in @alice
    get kitchen_cabinet_ticket_path(foreign)
    assert_response :not_found
  end

  test "a read-only user can browse; a no-access user is redirected" do
    make_ticket(owner: @root, person: "Root Grievance")
    reader = User.create!(organization: @org, role: @read, name: "Reader", email: "reader@example.com", password: "password123")
    sign_in reader
    get kitchen_cabinet_tickets_path
    assert_response :success

    outsider = User.create!(organization: @org, role: @none, name: "Out", email: "out@example.com", password: "password123")
    sign_in outsider
    get kitchen_cabinet_tickets_path
    assert_redirected_to root_path
  end
end
