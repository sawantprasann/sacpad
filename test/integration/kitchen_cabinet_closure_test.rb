require "test_helper"

# Story 1.7 — two-step closure + voter-sentiment capture over HTTP. Voter + sentiment optional;
# an unmatched / missing voter still closes. Write ∩ subtree gated.
class KitchenCabinetClosureTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @cat = TicketCategory.create!(name: "Water", slug: "water", display_order: 1)

    @write = Role.create!(name: "Field", slug: "field")
    @write.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "write")
    @read = Role.create!(name: "Viewer", slug: "viewer")
    @read.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "read")

    @root  = User.create!(organization: @org, role: @write, name: "Root",  email: "root@example.com",  password: "password123")
    @alice = User.create!(organization: @org, role: @write, name: "Alice", email: "alice@example.com", password: "password123", parent: @root)
    @bob   = User.create!(organization: @org, role: @write, name: "Bob",   email: "bob@example.com",   password: "password123", parent: @root)
  end

  def in_progress_ticket(owner: @alice)
    ActsAsTenant.with_tenant(@org) do
      t = KitchenCabinet::Ticket.create!(owner: owner, ticket_category: @cat, person_name: "P-#{owner.name}")
      t.change_status!(to: "in_progress", actor: owner)
      t
    end
  end

  test "closing with a matched voter writes sentiment to the VoterSentiment" do
    voter = Voter.create!(voter_id: "VTR1", first_name: "Asha", last_name: "Kumar")
    ActsAsTenant.with_tenant(@org) do
      VoterSentiment.create!(voter: voter, organization: @org)
    end

    t = in_progress_ticket
    sign_in @alice
    post kitchen_cabinet_ticket_closure_path(t),
      params: { closure_date: Date.current.to_s, voter_id: "VTR1", sentiment: "pleased" }
    assert_redirected_to kitchen_cabinet_ticket_path(t)
    assert t.reload.closed?
    assert_equal "VTR1", t.voter_id

    ActsAsTenant.with_tenant(@org) do
      voter_sentiment = VoterSentiment.find_by(voter: voter, organization: @org)
      assert voter_sentiment.sentiment_pleased?
      assert_equal @alice.id, voter_sentiment.sentiment_updated_by_id
    end
  end

  test "closing without a voter still closes and writes no sentiment" do
    t = in_progress_ticket
    sign_in @alice
    post kitchen_cabinet_ticket_closure_path(t), params: { closure_date: Date.current.to_s }
    assert t.reload.closed?
    assert_nil t.voter_id
  end

  test "closing with an unmatched voter_id still closes (loose lookup)" do
    t = in_progress_ticket
    sign_in @alice
    post kitchen_cabinet_ticket_closure_path(t), params: { voter_id: "NOPE", sentiment: "pleased" }
    assert t.reload.closed?
    assert_equal "NOPE", t.voter_id
  end

  test "the quiet confirmation copy is shown after closing" do
    t = in_progress_ticket
    sign_in @alice
    post kitchen_cabinet_ticket_closure_path(t), params: { closure_date: Date.current.to_s }
    follow_redirect!
    assert_match "On record as help delivered", @response.body
  end

  test "an open ticket cannot be closed via the flow (guarded)" do
    t = ActsAsTenant.with_tenant(@org) do
      KitchenCabinet::Ticket.create!(owner: @alice, ticket_category: @cat, person_name: "Open")
    end
    sign_in @alice
    get new_kitchen_cabinet_ticket_closure_path(t)
    assert_redirected_to kitchen_cabinet_ticket_path(t)
    assert_not t.reload.closed?
  end

  test "a read-only user cannot close (404)" do
    reader = User.create!(organization: @org, role: @read, name: "Reader", email: "reader@example.com", password: "password123", parent: @root)
    t = in_progress_ticket(owner: reader)
    sign_in reader
    post kitchen_cabinet_ticket_closure_path(t), params: { closure_date: Date.current.to_s }
    assert_response :not_found
  end

  test "an out-of-subtree ticket cannot be closed (404)" do
    t = in_progress_ticket(owner: @bob)
    sign_in @alice
    post kitchen_cabinet_ticket_closure_path(t), params: { closure_date: Date.current.to_s }
    assert_response :not_found
  end
end
