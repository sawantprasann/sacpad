require "test_helper"

# Story 1.1 — the ticket-category catalog is managed via the Story 0.4 reusable Console editor,
# Admin-only. It also exercises the boolean/integer field support added to the shared _form.
class ConsoleTicketCategoriesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123", tier: :full)
  end

  test "the ticket-category catalog requires admin auth" do
    get "/console/ticket_categories"
    assert_redirected_to new_admin_session_path
  end

  test "the Console sidebar links to the ticket-category catalog" do
    sign_in @admin
    get "/console/ticket_categories"
    assert_response :success
    assert_select "a[href=?]", "/console/ticket_categories"
  end

  test "an admin can list and create a category via the shared editor" do
    sign_in @admin
    get "/console/ticket_categories"
    assert_response :success

    assert_difference -> { TicketCategory.count }, 1 do
      post "/console/ticket_categories",
        params: { record: { name: "Sanitation", slug: "sanitation", active: "1", display_order: "13" } }
    end
    assert_redirected_to "/console/ticket_categories"

    follow_redirect!
    assert_match "Sanitation", @response.body

    created = TicketCategory.find_by(slug: "sanitation")
    assert created.active?
    assert_equal 13, created.display_order
  end

  test "an admin can toggle a category inactive" do
    sign_in @admin
    cat = TicketCategory.create!(name: "Water", slug: "water", display_order: 1, active: true)

    patch "/console/ticket_categories/#{cat.id}", params: { record: { active: "0" } }
    assert_redirected_to "/console/ticket_categories"
    assert_not cat.reload.active?
  end
end
