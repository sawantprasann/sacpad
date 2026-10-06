require "test_helper"
require_relative "../../support/tenant_isolation"

module KitchenCabinet
  # Story 1.2 — Ticket is the first org-scoped DOMAIN model; the per-model isolation test is a
  # release blocker (FR11). Uses the shared TenantIsolation helpers.
  class TicketTest < ActiveSupport::TestCase
    include TenantIsolation

    setup do
      @category = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)
      ActsAsTenant.without_tenant do
        @org_a = Organization.create!(name: "Org A")
        @org_b = Organization.create!(name: "Org B")
        @role  = Role.create!(name: "Field", slug: "field")
        @user_a = User.create!(organization: @org_a, role: @role, name: "A", email: "a@example.com", password: "password123")
        @user_b = User.create!(organization: @org_b, role: @role, name: "B", email: "b@example.com", password: "password123")
        @b_ticket = Ticket.create!(organization: @org_b, owner: @user_b, ticket_category: @category, person_name: "Foo")
      end
    end

    test "is org-scoped domain data (OrganizationScoped)" do
      assert Ticket.ancestors.include?(OrganizationScoped)
    end

    test "status defaults to open" do
      ActsAsTenant.with_tenant(@org_a) { assert Ticket.new.open? }
    end

    test "person_name is required" do
      ActsAsTenant.with_tenant(@org_a) do
        t = Ticket.new(owner: @user_a, ticket_category: @category)
        assert_not t.valid?
        assert t.errors[:person_name].any?
      end
    end

    test "belongs to owner + category, supports attachments, and gets a ticket_number" do
      ActsAsTenant.with_tenant(@org_a) do
        t = Ticket.create!(owner: @user_a, ticket_category: @category, person_name: "Asha")
        assert_equal @user_a, t.owner
        assert_equal @category, t.ticket_category
        assert_respond_to t, :attachments
        assert t.ticket_number.present?
        assert_equal Date.current, t.reported_at
      end
    end

    test "a query with no tenant set raises" do
      assert_raises_without_tenant(Ticket)
    end

    test "Org A cannot read/update/delete an Org B ticket" do
      assert_tenant_isolated(Ticket, owner: @org_a, foreign_record: @b_ticket)
    end
  end
end
