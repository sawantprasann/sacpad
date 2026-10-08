require "test_helper"

module KitchenCabinet
  # Story 1.6 — voter_id is a model-level invariant: settable only once closed; loose Voter lookup.
  class TicketVoterGateTest < ActiveSupport::TestCase
    setup do
      @cat  = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)
      @org  = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
      @role = ActsAsTenant.without_tenant { Role.create!(name: "Field", slug: "field") }
      @user = ActsAsTenant.without_tenant do
        User.create!(organization: @org, role: @role, name: "U", email: "u@example.com", password: "password123")
      end
    end

    def new_open_ticket
      Ticket.create!(owner: @user, ticket_category: @cat, person_name: "P")
    end

    def close!(ticket)
      ticket.change_status!(to: "in_progress", actor: @user)
      ticket.change_status!(to: "closed", actor: @user)
    end

    test "voter_id cannot be set while the ticket is not closed" do
      ActsAsTenant.with_tenant(@org) do
        t = new_open_ticket
        t.voter_id = "VTR123"
        assert_not t.valid?
        assert t.errors[:voter_id].any?
        assert_not t.save
        assert_nil t.reload.voter_id
      end
    end

    test "voter_id can be set once the ticket is closed" do
      ActsAsTenant.with_tenant(@org) do
        t = new_open_ticket
        close!(t)
        assert t.update(voter_id: "VTR123")
        assert_equal "VTR123", t.reload.voter_id
      end
    end

    test "matched_voter is a loose lookup — nil when none, the Voter when present" do
      ActsAsTenant.with_tenant(@org) do
        t = new_open_ticket
        close!(t)
        t.update!(voter_id: "VTR999")
        assert_nil t.matched_voter

        voter = Voter.create!(voter_id: "VTR999", first_name: "Asha", last_name: "Kumar")
        assert_equal voter, t.matched_voter
      end
    end
  end
end
