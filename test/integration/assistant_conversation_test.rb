require "test_helper"

class AssistantConversationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Chat Org") }
    state = State.create!(name: "Maharashtra")
    assembly = state.loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur")
    assembly.villages.create!(name: "Nimgaon")
    @org.update!(constituency: assembly)
    role = Role.create!(name: "Chat", slug: "chat-#{SecureRandom.hex(4)}")
    role.role_permissions.create!(module_name: "kitchen_cabinet", access_level: "read")
    @user = User.create!(organization: @org, role: role, name: "Asha", email: "chat-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @outsider = Role.create!(name: "No modules", slug: "none-#{SecureRandom.hex(4)}")
    @blocked = User.create!(organization: @org, role: @outsider, name: "Out", email: "out-#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  test "the ask page lists the menus and posts a question" do
    sign_in @user
    get assistant_conversations_path
    assert_response :success
    assert_match "What is the past result?", response.body
    assert_match "How many beneficiaries are in Nimgaon?", response.body

    post assistant_conversations_path, params: { body: "What is the past result?" }
    assert_response :redirect
    follow_redirect!
    assert_match "The assistant is not connected yet", response.body
  end

  test "another question can be sent while the first is still answering" do
    sign_in @user
    get assistant_conversations_path
    assert_match "turbo-cable-stream-source", response.body

    conversation = AssistantConversation.unscoped.order(:id).last
    assert_enqueued_jobs 2, only: Assistant::AnswerJob do
      post assistant_conversations_path,
        params: { body: "How many beneficiaries are in Nimgaon?", conversation_id: conversation.id, pending_id: "pending-11111111-1111-1111-1111-111111111111" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      post assistant_conversations_path,
        params: { body: "What is the past result?", conversation_id: conversation.id, pending_id: "pending-22222222-2222-2222-2222-222222222222" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "<turbo-stream", response.body
    assert_no_match "The assistant is not connected yet", response.body

    perform_enqueued_jobs
    travel 3.seconds
    perform_enqueued_jobs
    assert_equal 2, AssistantMessage.unscoped.from_assistant.where(assistant_conversation_id: conversation.id).count
  end

  test "a user with no module access does not get the page" do
    sign_in @blocked
    get assistant_conversations_path
    assert_response :not_found
  end
end
