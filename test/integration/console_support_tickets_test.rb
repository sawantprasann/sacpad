require "test_helper"

class ConsoleSupportTicketsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Console Support Org") }
    @other = ActsAsTenant.without_tenant { Organization.create!(name: "Hidden Support Org") }
    @role = Role.create!(name: "Console support user", slug: "console-support-user")
    @user = User.create!(organization: @org, role: @role, name: "Meera Shah", email: "meera-console-support@example.com", password: "password123")
    @other_user = User.create!(organization: @other, role: @role, name: "Hidden User", email: "hidden-console-support@example.com", password: "password123")
    @admin = Admin.create!(name: "Platform", email: "platform-support@example.com", password: "password123", tier: :full)
    @ops = Admin.create!(name: "Ops", email: "ops-support@example.com", password: "password123", tier: :ops)
    @ops.organizations << @org

    @ticket = ActsAsTenant.with_tenant(@org) do
      SupportTicket.create!(organization: @org, user: @user, subject: "Map will not load", opening_body: "The village page stays blank.", category: :technical)
    end
    @hidden = ActsAsTenant.with_tenant(@other) do
      SupportTicket.create!(organization: @other, user: @other_user, subject: "Secret complaint", opening_body: "Should stay hidden.", category: :general)
    end
  end

  test "an organization user cannot open the console inbox" do
    sign_in @user
    get console_support_tickets_path
    assert_redirected_to new_admin_session_path
  end

  test "a full admin sees every complaint and can reply" do
    sign_in @admin
    get console_support_tickets_path
    assert_response :success
    assert_match "Map will not load", @response.body
    assert_match "Secret complaint", @response.body
    assert_match @org.name, @response.body

    get console_support_tickets_path(q: "Meera")
    assert_match "Map will not load", @response.body
    assert_no_match "Secret complaint", @response.body

    post reply_console_support_ticket_path(@ticket), params: {
      support_message: { body: "We shipped a fix. Please try again." },
      support_ticket: { status: "solved" }
    }
    assert_redirected_to console_support_ticket_path(@ticket)
    ActsAsTenant.with_tenant(@org) do
      @ticket.reload
      assert @ticket.solved?
      reply = @ticket.messages.order(:id).last
      assert_equal @admin, reply.author
      assert_equal "We shipped a fix. Please try again.", reply.body
    end

    follow_redirect!
    assert_match "We shipped a fix. Please try again.", @response.body
    assert_match "Solved", @response.body
  end

  test "an admin can change status without writing a reply" do
    sign_in @admin
    post reply_console_support_ticket_path(@ticket), params: {
      support_message: { body: "  " },
      support_ticket: { status: "in_progress" }
    }
    assert_redirected_to console_support_ticket_path(@ticket)
    ActsAsTenant.with_tenant(@org) do
      assert @ticket.reload.in_progress?
      assert_equal 1, @ticket.messages.count
    end
  end

  test "an ops admin only sees tickets for assigned organizations" do
    sign_in @ops
    get console_support_tickets_path
    assert_response :success
    assert_match "Map will not load", @response.body
    assert_no_match "Secret complaint", @response.body

    get console_support_ticket_path(@hidden)
    assert_response :not_found
  end

  test "an admin sees images the user attached" do
    ActsAsTenant.with_tenant(@org) do
      @ticket.messages.first.images.attach(
        io: File.open(file_fixture("photo.png")), filename: "screen.png", content_type: "image/png"
      )
    end

    sign_in @admin
    get console_support_ticket_path(@ticket)
    assert_response :success
    assert_select "img[alt=?]", "screen.png"
  end
end
