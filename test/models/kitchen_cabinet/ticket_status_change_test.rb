require "test_helper"
require_relative "../../support/tenant_isolation"

module KitchenCabinet
  # Story 1.4 — the Tier-2 status-change log is tenant data; the isolation test is a release gate.
  class TicketStatusChangeTest < ActiveSupport::TestCase
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
        @b_change = TicketStatusChange.create!(organization: @org_b, ticket: @tb, actor: @ub,
                                               from_status: "open", to_status: "in_progress")
      end
    end

    test "is org-scoped domain data" do
      assert TicketStatusChange.ancestors.include?(OrganizationScoped)
    end

    test "belongs to ticket and actor" do
      assert_equal @tb, @b_change.ticket
      assert_equal @ub, @b_change.actor
    end

    test "a query with no tenant set raises" do
      assert_raises_without_tenant(TicketStatusChange)
    end

    test "Org A cannot read/update/delete an Org B status change" do
      assert_tenant_isolated(TicketStatusChange, owner: @org_a, foreign_record: @b_change)
    end
  end
end
