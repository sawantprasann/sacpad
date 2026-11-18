require "test_helper"

class AssistantConversationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

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

  test "a question returns the answer without a page reload" do
    sign_in @user
    post assistant_conversations_path,
      params: { body: "How many beneficiaries are in Nimgaon?" },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "<turbo-stream", response.body
    assert_match "The assistant is not connected yet", response.body
    assert_match %(target="chat-messages"), response.body
    assert_match %(target="assistant-thinking"), response.body
  end

  test "a user with no module access does not get the page" do
    sign_in @blocked
    get assistant_conversations_path
    assert_response :not_found
  end
end
