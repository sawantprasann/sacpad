require "test_helper"
require "roo"

# Story 1.8 — Excel export of the viewer-scoped, filtered ticket list (FR49). Parsed with Roo to
# assert real content + scoping.
class KitchenCabinetExportTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @cat = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)
    @write = Role.create!(name: "Field", slug: "field")
    @write.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "write")
    @root  = User.create!(organization: @org, role: @write, name: "Root",  email: "root@example.com",  password: "password123")
    @alice = User.create!(organization: @org, role: @write, name: "Alice", email: "alice@example.com", password: "password123", parent: @root)
    @bob   = User.create!(organization: @org, role: @write, name: "Bob",   email: "bob@example.com",   password: "password123", parent: @root)
  end

  def xlsx_cells
    file = Tempfile.new([ "export", ".xlsx" ])
    file.binmode
    file.write(@response.body)
    file.rewind
    Roo::Excelx.new(file.path).sheet(0).to_a.flatten.map(&:to_s)
  ensure
    file&.close
  end

  test "the export is scoped to the viewer's subtree" do
    mine = ActsAsTenant.with_tenant(@org) { KitchenCabinet::Ticket.create!(owner: @alice, ticket_category: @cat, person_name: "Mine Asha") }
    peer = ActsAsTenant.with_tenant(@org) { KitchenCabinet::Ticket.create!(owner: @bob, ticket_category: @cat, person_name: "Peer Bimal") }
    sign_in @alice
    get kitchen_cabinet_tickets_path(format: :xlsx)
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", @response.media_type

    cells = xlsx_cells
    assert_includes cells, mine.person_name
    assert_not_includes cells, peer.person_name
  end

  test "the export respects the status filter" do
    ActsAsTenant.with_tenant(@org) do
      KitchenCabinet::Ticket.create!(owner: @alice, ticket_category: @cat, person_name: "Open One")
      t = KitchenCabinet::Ticket.create!(owner: @alice, ticket_category: @cat, person_name: "Blocked One")
      t.change_status!(to: "in_progress", actor: @alice)
      t.change_status!(to: "blocked", actor: @alice)
    end
    sign_in @alice
    get kitchen_cabinet_tickets_path(format: :xlsx, status: "blocked")
    assert_response :success

    cells = xlsx_cells
    assert_includes cells, "Blocked One"
    assert_not_includes cells, "Open One"
  end
end
