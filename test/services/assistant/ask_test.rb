require "test_helper"

class AssistantAskTest < ActiveSupport::TestCase
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Ask Org") }
    state = State.create!(name: "Maharashtra")
    loksabha = state.loksabhas.create!(name: "Baramati")
    @assembly = loksabha.assemblies.create!(name: "Indapur")
    @other_assembly = loksabha.assemblies.create!(name: "Elsewhere")
    @village = @assembly.villages.create!(name: "Nimgaon", native_name: "निमगाव")
    @same_name = @other_assembly.villages.create!(name: "Far")
    @org.update!(constituency: loksabha)
    @booth = @village.booths.create!(number: "12", name: "School")

    @role = Role.create!(name: "Asker", slug: "ask-#{SecureRandom.hex(4)}")
    %w[kitchen_cabinet cadre_program ground_reports pr voter_lists booth_management social_media].each do |mod|
      @role.role_permissions.create!(module_name: mod, access_level: "read")
    end
    @user = User.create!(organization: @org, role: @role, name: "Asha", email: "ask-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @category = TicketCategory.create!(name: "Water", slug: "water-#{SecureRandom.hex(4)}", display_order: 1)
  end

  test "beneficiary, voter, sarpanch, booth, cadre, and past-result questions use only this organization" do
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Other") }
    other.update!(constituency: @assembly)
    ActsAsTenant.with_tenant(@org) do
      KitchenCabinet::Ticket.create!(owner: @user, ticket_category: @category, person_name: "Asha Patil", village: "Nimgaon", reported_at: Date.current)
      voter = Voter.create!(voter_id: "ASK#{SecureRandom.hex(4)}", first_name: "Ravi", last_name: "Kale", mobile: "9998887776", village: @village, booth: @booth)
      VoterSentiment.create!(voter: voter, sentiment_status: :displeased)
      GroundReports::VillageLocalAdminContact.create!(village: @village, name: "Suresh", role_title: "Sarpanch", phone: "9876543210")
      GroundReports::VillageLocalKaryakarta.create!(village: @village, name: "Meena", phone: "9123456780")
      activity = CadreProgram::CadreActivity.new(owner: @user, category: :leadership_meets, impact_notes: "Road")
      activity.build_leadership_meet(whom_to_meet: "MLA")
      activity.save!
    end
    ActsAsTenant.with_tenant(other) do
      other_user = User.create!(organization: other, role: @role, name: "Other", email: "other-#{SecureRandom.hex(4)}@example.com", password: "password123")
      KitchenCabinet::Ticket.create!(owner: other_user, ticket_category: @category, person_name: "Hidden", village: "Nimgaon", reported_at: Date.current)
    end

    ActsAsTenant.with_tenant(@org) do
      conversation = AssistantConversation.create!(user: @user, organization: @org)
      answer = Assistant::Ask.new(
        user: @user, conversation: conversation, question: "beneficiaries in Nimgaon",
        client: fake("count_beneficiaries", "place_name" => "Nimgaon", "place_kind" => "village")
      ).call
      assert_includes answer.body, "1 beneficiary"
      assert_includes answer.body, "Asha Patil"
      assert_not_includes answer.body, "Hidden"

      answer = Assistant::Ask.new(
        user: @user, conversation: conversation, question: "displeased voters",
        client: fake("list_voters", "place_name" => "निमगाव", "sentiment" => "displeased")
      ).call
      assert_includes answer.body, "Ravi Kale"
      assert_not_includes answer.body, "9998887776"

      answer = Assistant::Ask.new(
        user: @user, conversation: conversation, question: "sarpanch",
        client: fake("local_admin_contact", "place_name" => "Nimgaon", "role" => "sarpanch")
      ).call
      assert_includes answer.body, "Suresh"
      assert_includes answer.body, "9876543210"

      answer = Assistant::Ask.new(
        user: @user, conversation: conversation, question: "booth 12",
        client: fake("booth_status", "place_name" => "12", "place_kind" => "booth")
      ).call
      assert_includes answer.body, "Booth 12"
      assert_includes answer.body, "1 voters"

      answer = Assistant::Ask.new(
        user: @user, conversation: conversation, question: "leadership meets",
        client: fake("cadre_activities", "category" => "leadership_meets")
      ).call
      assert_includes answer.body, "Leadership Meets: 1"
      assert_includes answer.body, "MLA"

      answer = Assistant::Ask.new(
        user: @user, conversation: conversation, question: "past result",
        client: fake("past_result")
      ).call
      assert_includes answer.body, "No past result"
      assert_equal "assistant.past_result", ActivityLog.order(:id).last.action
    end
  end

  test "a role without social media is not offered that tool" do
    @role.role_permissions.find_by!(module_name: "social_media").update!(access_level: "none")
    ActsAsTenant.with_tenant(@org) do
      client = fake("social_pages")
      conversation = AssistantConversation.create!(user: @user, organization: @org)
      answer = Assistant::Ask.new(user: @user, conversation: conversation, question: "which pages are connected", client: client).call
      assert_includes answer.body, "I can answer"
      assert_not_includes client.tools.map { |tool| tool.dig(:function, :name) }, "social_pages"
      assert_includes client.tools.map { |tool| tool.dig(:function, :name) }, "pr_records"
    end
  end

  test "two villages with the same name ask which one" do
    @same_name.update!(name: "Nimgaon")
    ActsAsTenant.with_tenant(@org) do
      conversation = AssistantConversation.create!(user: @user, organization: @org)
      answer = Assistant::Ask.new(
        user: @user, conversation: conversation, question: "voters in Nimgaon",
        client: fake("list_voters", "place_name" => "Nimgaon")
      ).call
      assert_includes answer.body, "Which place"
      assert_includes answer.body, "Indapur"
      assert_includes answer.body, "Elsewhere"
    end
  end

  private

  def fake(name, arguments = {})
    FakeAssistantClient.new(name: name, arguments: arguments)
  end

  class FakeAssistantClient
    attr_reader :tools

    def initialize(name:, arguments: {})
      @name = name
      @arguments = arguments
    end

    def configured? = true

    def tool_call(messages:, tools:)
      @tools = tools
      Assistant::OllamaClient::ToolCall.new(name: @name, arguments: @arguments)
    end

    def complete(messages:)
      "Draft"
    end
  end
end
