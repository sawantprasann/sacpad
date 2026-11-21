require "test_helper"

class AssistantOllamaClientTest < ActiveSupport::TestCase
  test "a blank url is not configured" do
    client = Assistant::OllamaClient.new(url: nil, model: "qwen3:8b")
    assert_not client.configured?
  end

  test "the first tool call is read from an Ollama response" do
    call = Assistant::OllamaClient.parse_tool_call(
      "message" => {
        "tool_calls" => [
          { "function" => { "name" => "past_result", "arguments" => { "year" => 2024 } } }
        ]
      }
    )
    assert_equal "past_result", call.name
    assert_equal 2024, call.arguments["year"]
  end

  test "an invented prose reply is ignored" do
    assert_nil Assistant::OllamaClient.parse_tool_call("message" => { "content" => "There are 10 beneficiaries." })
  end
end
