require "test_helper"

class SupportTicketsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Support Org") }
    @other_org = ActsAsTenant.without_tenant { Organization.create!(name: "Other Support Org") }
    @role = Role.create!(name: "Support user", slug: "support-user")
    @user = User.create!(organization: @org, role: @role, name: "Meera", email: "meera-support@example.com", password: "password123")
    @colleague = User.create!(organization: @org, role: @role, name: "Kabir", email: "kabir-support@example.com", password: "password123")
    @outsider = User.create!(organization: @other_org, role: @role, name: "Outsider", email: "outsider-support@example.com", password: "password123")
  end

  test "guests are sent to sign in" do
    get support_tickets_path
    assert_redirected_to new_user_session_path
  end

  test "a signed-in user can raise a complaint and see only their own tickets" do
    colleague_ticket = ActsAsTenant.with_tenant(@org) do
      SupportTicket.create!(organization: @org, user: @colleague, subject: "Colleague issue", opening_body: "Hidden", category: :account)
    end

    sign_in @user
    get support_tickets_path
    assert_response :success
    assert_select "h1", text: "Support tickets"
    assert_select "a", text: "Support"
    assert_match "No tickets match.", @response.body

    assert_difference -> { SupportTicket.unscoped.count }, 1 do
      post support_tickets_path, params: { support_ticket: {
        subject: "Export fails", category: "technical", opening_body: "The Excel file never downloads.",
        organization_id: @other_org.id, user_id: @colleague.id
      } }
    end

    ticket = SupportTicket.unscoped.order(:id).last
    assert_redirected_to support_ticket_path(ticket)
    assert_equal @user, ticket.user
    assert_equal @org, ticket.organization
    assert ticket.technical?
    follow_redirect!
    assert_match "Export fails", @response.body
    assert_match "The Excel file never downloads.", @response.body

    get support_tickets_path
    assert_match ticket.ticket_number, @response.body
    assert_no_match "Colleague issue", @response.body

    get support_ticket_path(colleague_ticket)
    assert_response :not_found
  end

  test "a complaint can include images and a reply can add more" do
    sign_in @user
    photo = fixture_file_upload("photo.png", "image/png")
    assert_difference -> { SupportTicket.unscoped.count }, 1 do
      post support_tickets_path, params: { support_ticket: {
        subject: "Broken chart", category: "technical", opening_body: "The pie chart is blank.",
        images: [ photo ]
      } }
    end

    ticket = SupportTicket.unscoped.order(:id).last
    assert_redirected_to support_ticket_path(ticket)
    follow_redirect!
    assert_select "img[alt=?]", "photo.png"

    reply_photo = fixture_file_upload("photo.png", "image/png")
    post reply_support_ticket_path(ticket), params: { support_message: { body: "Another shot", images: [ reply_photo ] } }
    assert_redirected_to support_ticket_path(ticket)
    ActsAsTenant.with_tenant(@org) do
      assert_equal 2, ticket.messages.flat_map { |message| message.images.attachments }.size
    end
  end

  test "a complaint rejects a file that is not an image" do
    sign_in @user
    notes = fixture_file_upload("photo.png", "text/plain")
    assert_no_difference -> { SupportTicket.unscoped.count } do
      post support_tickets_path, params: { support_ticket: {
        subject: "Notes", category: "general", opening_body: "Attached", images: [ notes ]
      } }
    end
    assert_response :unprocessable_entity
    assert_match "JPEG, PNG, GIF, or WebP", @response.body
  end

  test "a blank complaint is rejected" do
    sign_in @user
    post support_tickets_path, params: { support_ticket: { subject: "", category: "general", opening_body: "" } }
    assert_response :unprocessable_entity
    assert_match "Subject can&#39;t be blank", @response.body
  end

  test "the person who raised a solved ticket can reply and reopen it" do
    ticket = ActsAsTenant.with_tenant(@org) do
      SupportTicket.create!(organization: @org, user: @user, subject: "Login loop", opening_body: "I bounce back to sign in.", category: :account)
    end
    ticket.update!(status: :solved)

    sign_in @user
    post reply_support_ticket_path(ticket), params: { support_message: { body: "It is still happening." } }
    assert_redirected_to support_ticket_path(ticket)
    ActsAsTenant.with_tenant(@org) do
      assert_equal "pending", ticket.reload.status
      assert_equal "It is still happening.", ticket.messages.order(:id).last.body
    end
  end

  test "pending includes tickets that are not solved" do
    ActsAsTenant.with_tenant(@org) do
      open_ticket = SupportTicket.create!(organization: @org, user: @user, subject: "Still open", opening_body: "Waiting", category: :general)
      open_ticket.update!(status: :in_progress)
      SupportTicket.create!(organization: @org, user: @user, subject: "Already fixed", opening_body: "Done", category: :general).update!(status: :solved)
    end

    sign_in @user
    get support_tickets_path(status: "pending")
    assert_match "Still open", @response.body
    assert_no_match "Already fixed", @response.body

    get support_tickets_path(status: "solved")
    assert_match "Already fixed", @response.body
    assert_no_match "Still open", @response.body

    get support_tickets_path(q: "fixed")
    assert_match "Already fixed", @response.body
    assert_no_match "Still open", @response.body
  end
end
