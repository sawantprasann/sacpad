require "test_helper"

# Story 1.5 — add follow-ups over HTTP: KC-write ∩ subtree gated (no extra capability), newest-first.
class KitchenCabinetFollowUpsTest < ActionDispatch::IntegrationTest
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

  test "a write user adds a follow-up with an attachment; created_by comes from the session" do
    t = ticket_for(@alice)
    sign_in @alice
    photo = fixture_file_upload("photo.png", "image/png")
    assert_difference -> { KitchenCabinet::TicketFollowUp.unscoped.count }, 1 do
      post kitchen_cabinet_ticket_follow_ups_path(t),
        params: { ticket_follow_up: { note: "Called the ward officer", attachment: photo } }
    end
    fu = KitchenCabinet::TicketFollowUp.unscoped.order(:id).last
    assert_equal @alice, fu.created_by
    assert fu.attachment.attached?
    assert_redirected_to kitchen_cabinet_ticket_path(t)
  end

  test "entries render newest-first on the detail" do
    t = ticket_for(@alice)
    ActsAsTenant.with_tenant(@org) do
      t.follow_ups.create!(created_by: @alice, note: "First note", created_at: 2.hours.ago)
      t.follow_ups.create!(created_by: @alice, note: "Second note", created_at: 1.hour.ago)
    end
    sign_in @alice
    get kitchen_cabinet_ticket_path(t)
    assert_response :success
    assert_operator @response.body.index("Second note"), :<, @response.body.index("First note")
  end

  test "a blank note creates no row" do
    t = ticket_for(@alice)
    sign_in @alice
    assert_no_difference -> { KitchenCabinet::TicketFollowUp.unscoped.count } do
      post kitchen_cabinet_ticket_follow_ups_path(t), params: { ticket_follow_up: { note: "" } }
    end
  end

  test "a read-only user cannot add a follow-up (404)" do
    reader = User.create!(organization: @org, role: @read, name: "Reader", email: "reader@example.com", password: "password123", parent: @root)
    t = ticket_for(reader)
    sign_in reader
    post kitchen_cabinet_ticket_follow_ups_path(t), params: { ticket_follow_up: { note: "x" } }
    assert_response :not_found
  end

  test "a ticket outside the viewer's subtree cannot receive a follow-up (404)" do
    t = ticket_for(@bob)
    sign_in @alice
    post kitchen_cabinet_ticket_follow_ups_path(t), params: { ticket_follow_up: { note: "x" } }
    assert_response :not_found
  end
end
