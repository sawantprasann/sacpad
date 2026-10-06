require "test_helper"
require_relative "../../support/tenant_isolation"

module KitchenCabinet
  # Story 1.5 — the follow-up log is tenant data; the isolation test is a release gate.
  class TicketFollowUpTest < ActiveSupport::TestCase
    include TenantIsolation

    setup do
      @cat = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)
      ActsAsTenant.without_tenant do
        @org_a = Organization.create!(name: "Org A")
        @org_b = Organization.create!(name: "Org B")
        @role = Role.create!(name: "Field", slug: "field")
        @ua = User.create!(organization: @org_a, role: @role, name: "UA", email: "ua@example.com", password: "password123")
        @ub = User.create!(organization: @org_b, role: @role, name: "UB", email: "ub@example.com", password: "password123")
        @tb = Ticket.create!(organization: @org_b, owner: @ub, ticket_category: @cat, person_name: "B")
        @b_fu = TicketFollowUp.create!(organization: @org_b, ticket: @tb, created_by: @ub, note: "did x")
      end
    end

    test "is org-scoped domain data" do
      assert TicketFollowUp.ancestors.include?(OrganizationScoped)
    end

    test "note is required" do
      ActsAsTenant.with_tenant(@org_b) do
        fu = TicketFollowUp.new(ticket: @tb, created_by: @ub)
        assert_not fu.valid?
        assert fu.errors[:note].any?
      end
    end

    test "belongs to ticket + created_by and supports an attachment" do
      assert_equal @tb, @b_fu.ticket
      assert_equal @ub, @b_fu.created_by
      assert_respond_to @b_fu, :attachment
    end

    test "a query with no tenant set raises" do
      assert_raises_without_tenant(TicketFollowUp)
    end

    test "Org A cannot read/update/delete an Org B follow-up" do
      assert_tenant_isolated(TicketFollowUp, owner: @org_a, foreign_record: @b_fu)
    end
  end
end
