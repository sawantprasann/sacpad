require "test_helper"

# Story 1.2 — mobile-first ticket capture: pre-filled form, write-gated create, org from session.
class KitchenCabinetTicketsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @water = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)

    @write_role = Role.create!(name: "Field", slug: "field")
    @write_role.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "write")
    @read_role = Role.create!(name: "Viewer", slug: "viewer")
    @read_role.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "read")

    @writer = User.create!(organization: @org, role: @write_role, name: "Rohan", email: "rohan@example.com", password: "password123")
    @reader = User.create!(organization: @org, role: @read_role, name: "Nisha", email: "nisha@example.com", password: "password123")
  end

  def last_ticket = KitchenCabinet::Ticket.unscoped.order(:id).last

  test "a KC-write user sees the new-ticket form with a category dropdown" do
    sign_in @writer
    get new_kitchen_cabinet_ticket_path(category: "water")
    assert_response :success
    assert_select "div.max-w-xl", count: 0
    assert_select "h1", text: "Create ticket"
    assert_select "label", text: "Beneficiary name"
    assert_select "label", text: "Representative name"
    assert_select "label", text: "Village / ward"
    body = @response.body
    assert_operator body.index(">Village / ward<"), :<, body.index(">Representative name<")
    assert_operator body.index(">Representative name<"), :<, body.index(">Beneficiary name<")
    assert_select "input[name=?][maxlength=10][pattern=?][inputmode=numeric]", "ticket[mobile]", "[0-9]{10}"
    assert_select "[data-controller=datepicker] input[name=?]", "ticket[reported_at]"
    assert_select "button[type=submit].cursor-pointer", text: "Create ticket"
    assert_select "select[name=?] option[selected][value=?]", "ticket[ticket_category_id]", @water.id.to_s
  end

  test "a KC-write user can log a ticket with an attachment; owner + org come from the session" do
    sign_in @writer
    photo = fixture_file_upload("photo.png", "image/png")
    assert_difference -> { KitchenCabinet::Ticket.unscoped.count }, 1 do
      post kitchen_cabinet_tickets_path, params: { ticket: {
        ticket_category_id: @water.id, person_name: "Asha", representative_name: "Ramesh", village: "Wadi", mobile: "9990001111",
        description: "Pipe burst", nature_of_issue: "Leak", reported_value: "500.00",
        attachments: [ photo ] } }
    end
    t = last_ticket
    assert_redirected_to kitchen_cabinet_tickets_path(category: "water")
    assert_equal @writer, t.owner
    assert_equal "Ramesh", t.representative_name
    assert_equal @org, t.organization
    assert t.open?
    assert t.attachments.attached?
    assert t.ticket_number.present?
  end

  test "organization_id in params is ignored — the session's org wins" do
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Other") }
    sign_in @writer
    post kitchen_cabinet_tickets_path, params: { ticket: {
      ticket_category_id: @water.id, person_name: "Asha", organization_id: other.id } }
    assert_equal @org, last_ticket.organization
  end

  test "a KC read-only user cannot create a ticket (404, not 403)" do
    sign_in @reader
    post kitchen_cabinet_tickets_path, params: { ticket: { ticket_category_id: @water.id, person_name: "Asha" } }
    assert_response :not_found
  end
end
