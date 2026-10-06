require "test_helper"

module KitchenCabinet
  # Story 1.4 — transition rules + atomic Tier-2 logging + derivable time-to-resolution.
  class TicketStatusWorkflowTest < ActiveSupport::TestCase
    setup do
      @cat  = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)
      @org  = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
      @role = ActsAsTenant.without_tenant { Role.create!(name: "Field", slug: "field") }
      @user = ActsAsTenant.without_tenant do
        User.create!(organization: @org, role: @role, name: "U", email: "u@example.com", password: "password123")
      end
    end

    def new_ticket(**attrs)
      ActsAsTenant.with_tenant(@org) do
        Ticket.create!(owner: @user, ticket_category: @cat, person_name: "P", **attrs)
      end
    end

    test "may_change_to? follows the allowed workflow" do
      t = new_ticket
      assert t.may_change_to?("in_progress")
      assert_not t.may_change_to?("closed")
      assert_not t.may_change_to?("blocked")
    end

    test "change_status! advances and logs exactly one row with from/to/actor" do
      ActsAsTenant.with_tenant(@org) do
        t = Ticket.create!(owner: @user, ticket_category: @cat, person_name: "P")
        assert_difference -> { TicketStatusChange.count }, 1 do
          t.change_status!(to: "in_progress", actor: @user)
        end
        c = t.status_changes.last
        assert_equal "open", c.from_status
        assert_equal "in_progress", c.to_status
        assert_equal @user, c.actor
        assert t.in_progress?
      end
    end

    test "an illegal transition is refused and writes no row" do
      ActsAsTenant.with_tenant(@org) do
        t = Ticket.create!(owner: @user, ticket_category: @cat, person_name: "P")
        assert_no_difference -> { TicketStatusChange.count } do
          assert_raises(ArgumentError) { t.change_status!(to: "closed", actor: @user) }
        end
        assert t.reload.open?
      end
    end

    test "closing sets closed_at and makes resolution_duration derivable" do
      ActsAsTenant.with_tenant(@org) do
        t = Ticket.create!(owner: @user, ticket_category: @cat, person_name: "P", reported_at: Date.current - 2)
        assert_nil t.resolution_duration
        t.change_status!(to: "in_progress", actor: @user)
        t.change_status!(to: "closed", actor: @user)
        assert t.closed?
        assert_not_nil t.closed_at
        assert_operator t.resolution_duration, :>, 0
      end
    end
  end
end
