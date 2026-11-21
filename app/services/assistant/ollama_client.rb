module Assistant
  # HTTP client for a private Ollama server. This process has no database login.
  class OllamaClient
    Error = Class.new(StandardError)
    Timeout = Class.new(Error)
    ToolCall = Struct.new(:name, :arguments, keyword_init: true)

    def initialize(url: ENV["OLLAMA_URL"], model: ENV["OLLAMA_MODEL"].presence || "qwen3:8b")
      @url = url.to_s.chomp("/")
      @model = model
    end

    def configured? = @url.present?

    def tool_call(messages:, tools:)
      # Twelve tool schemas take about half a minute to read on this 2 GB CPU.
      body = post(model: @model, stream: false, messages: messages, tools: tools, read_timeout: 90, options: { num_ctx: 2048 })
      self.class.parse_tool_call(body)
    end

    def complete(messages:)
      body = post(model: @model, stream: false, messages: messages, read_timeout: 90)
      body.dig("message", "content").to_s.strip
    end

    def self.parse_tool_call(body)
      call = body.dig("message", "tool_calls")&.first
      function = call.is_a?(Hash) ? call["function"] : nil
      return if function.blank? || function["name"].blank?

      raw = function["arguments"]
      raw = JSON.parse(raw) if raw.is_a?(String)
      arguments = raw.is_a?(Hash) ? raw.stringify_keys : {}
      ToolCall.new(name: function["name"].to_s, arguments: arguments)
    rescue JSON::ParserError
      nil
    end

    private

    def post(read_timeout:, **payload)
      raise Error, "Ollama is not configured" unless configured?

      uri = URI.parse("#{@url}/api/chat")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = read_timeout
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      # Qwen3 writes a long "thinking" trace before the answer. On this CPU
      # droplet that trace blows the tool-call timeout. The app only reads
      # content and tool_calls.
      request.body = payload.merge(think: false).to_json
      response = http.request(request)
      raise Error, "Ollama returned #{response.code}: #{response.body.to_s.truncate(200)}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise Timeout
    rescue Errno::ECONNREFUSED, SocketError, EOFError, JSON::ParserError, SystemCallError
      raise Error, "Ollama is unavailable"
    end
  end
end
