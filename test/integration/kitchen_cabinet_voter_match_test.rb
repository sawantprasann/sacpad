require "test_helper"

class KitchenCabinetVoterMatchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    assembly = State.create!(name: "Maharashtra").loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur")
    @org.update!(constituency: assembly)
    @village = assembly.villages.create!(name: "Nimgaon")
    booth = @village.booths.create!(number: "14")
    @cat = TicketCategory.create!(name: "Water", slug: "water-match", display_order: 1)
    role = Role.create!(name: "Field", slug: "field-match")
    role.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "write")
    @user = User.create!(organization: @org, role: role, name: "Mina", email: "match@example.com", password: "password123")
    @asha = Voter.create!(voter_id: "AAA1111111", first_name: "Asha", last_name: "Patil", booth: booth, village: @village, sr_no: 3)
    @other = Voter.create!(voter_id: "BBB2222222", first_name: "Asha", middle_name: "R", last_name: "Patil", booth: booth, village: @village, sr_no: 4)
    sign_in @user
  end

  test "one exact name match links the voter and sets transit sentiment" do
    assert_difference -> { KitchenCabinet::Ticket.unscoped.count }, 1 do
      post kitchen_cabinet_tickets_path, params: { ticket: ticket_attrs("Asha R Patil") }
    end
    ticket = KitchenCabinet::Ticket.unscoped.order(:id).last
    assert_equal "BBB2222222", ticket.voter_id
    ActsAsTenant.with_tenant(@org) do
      assert VoterSentiment.find_by!(voter: @other).sentiment_transit?
    end
    assert_redirected_to kitchen_cabinet_tickets_path(category: "water-match")
  end

  test "several exact matches are listed so the representative can choose one" do
    Voter.create!(voter_id: "CCC3333333", first_name: "Asha", last_name: "Patil", booth: @asha.booth, village: @village, sr_no: 9)
    post kitchen_cabinet_tickets_path, params: { ticket: ticket_attrs("Asha Patil") }
    ticket = KitchenCabinet::Ticket.unscoped.order(:id).last
    assert_nil ticket.voter_id
    assert_redirected_to kitchen_cabinet_ticket_path(ticket)

    follow_redirect!
    assert_match "AAA1111111", @response.body
    assert_match "CCC3333333", @response.body
    assert_no_match(/BBB2222222/, @response.body)

    post match_voter_kitchen_cabinet_ticket_path(ticket), params: { matched_voter_id: @asha.id }
    assert_equal "AAA1111111", ticket.reload.voter_id
    ActsAsTenant.with_tenant(@org) do
      assert VoterSentiment.find_by!(voter: @asha).sentiment_transit?
    end

    patch status_kitchen_cabinet_ticket_path(ticket), params: { to_status: "in_progress" }
    assert_redirected_to kitchen_cabinet_ticket_path(ticket)
    assert ticket.reload.in_progress?
  end

  test "no match leaves the close flow unchanged and a closed ticket cannot be edited" do
    post kitchen_cabinet_tickets_path, params: { ticket: ticket_attrs("Nobody Here") }
    ticket = KitchenCabinet::Ticket.unscoped.order(:id).last
    assert_nil ticket.voter_id
    assert_redirected_to kitchen_cabinet_tickets_path(category: "water-match")

    ActsAsTenant.with_tenant(@org) do
      ticket.change_status!(to: "in_progress", actor: @user)
      ticket.change_status!(to: "closed", actor: @user)
    end
    get edit_kitchen_cabinet_ticket_path(ticket)
    assert_response :not_found
    patch kitchen_cabinet_ticket_path(ticket), params: { ticket: { person_name: "Changed" } }
    assert_response :not_found
    assert_equal "Nobody Here", ticket.reload.person_name
  end

  private

  def ticket_attrs(name)
    {
      person_name: name,
      village: "Nimgaon",
      description: "Water line",
      reported_at: Date.current,
      ticket_category_id: @cat.id
    }
  end
end
