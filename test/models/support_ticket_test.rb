require "test_helper"
require_relative "../support/tenant_isolation"

class SupportTicketTest < ActiveSupport::TestCase
  include TenantIsolation

  setup do
    @role = Role.create!(name: "Support field", slug: "support-field")
    ActsAsTenant.without_tenant do
      @org_a = Organization.create!(name: "Support Org A")
      @org_b = Organization.create!(name: "Support Org B")
      @user_a = User.create!(organization: @org_a, role: @role, name: "Asha", email: "asha-support@example.com", password: "password123")
      @user_b = User.create!(organization: @org_b, role: @role, name: "Bharat", email: "bharat-support@example.com", password: "password123")
      @foreign = SupportTicket.create!(
        organization: @org_b, user: @user_b, subject: "Other org", opening_body: "Not yours", category: :general
      )
    end
  end

  test "is org-scoped domain data" do
    assert_includes SupportTicket.ancestors, OrganizationScoped
    assert_includes SupportMessage.ancestors, OrganizationScoped
  end

  test "a ticket from another organization is invisible" do
    assert_tenant_isolated(SupportTicket, owner: @org_a, foreign_record: @foreign)
    assert_raises_without_tenant(SupportTicket)
  end

  test "create stores the complaint as the first message and numbers the ticket" do
    ticket = ActsAsTenant.with_tenant(@org_a) do
      created = SupportTicket.create!(
        organization: @org_a, user: @user_a, subject: "  Cannot export  ",
        opening_body: "  The button does nothing.  ", category: :technical
      )
      assert created.pending?
      assert created.technical?
      assert_equal "Cannot export", created.subject
      assert_equal "SP-#{@org_a.id}-00001", created.ticket_number
      assert_equal [ "The button does nothing." ], created.messages.map(&:body)
      assert_equal @user_a, created.messages.first.author
      created
    end
    assert ticket.persisted?
  end

  test "a complaint needs a subject and a description" do
    ticket = ActsAsTenant.with_tenant(@org_a) do
      SupportTicket.new(organization: @org_a, user: @user_a, subject: " ", opening_body: " ")
    end

    assert_not ticket.valid?
    assert ticket.errors[:subject].any?
    assert_includes ticket.errors.full_messages, "Complaint can't be blank"
  end
end
