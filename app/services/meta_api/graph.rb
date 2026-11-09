module MetaApi
  # Small Graph client for connecting Pages. Callers must not log the arguments:
  # params carry access tokens.
  class Graph
    VERSION = ENV.fetch("META_GRAPH_VERSION", "v26.0")
    HOST = "https://graph.facebook.com"

    class Error < StandardError
      attr_reader :code, :subcode, :type, :http_status

      def initialize(message, code: nil, subcode: nil, type: nil, http_status: nil, transient: false)
        super(message)
        @code = code
        @subcode = subcode
        @type = type
        @http_status = http_status
        @transient = transient
      end

      def token_error? = code.to_i == 190 || code.to_i == 102
      def rate_limited? = [ 4, 17, 32, 613 ].include?(code.to_i)
      def transient? = @transient || http_status.to_i >= 500 || [ 1, 2 ].include?(code.to_i)
    end

    class << self
      def get(path, params = {}) = request(:get, path, params)
      def post(path, params = {}) = request(:post, path, params)

      # Multipart upload for a photo or video. The access token stays in the body and is not logged.
      def upload(path, params = {})
        file = params.delete(:source)
        filename = params.delete(:filename).presence || "upload"
        content_type = params.delete(:content_type).presence || "application/octet-stream"
        bytes = file.respond_to?(:read) ? file.read : File.binread(file)
        uri = URI("#{HOST}/#{VERSION}#{path}")
        boundary = "----sacpad#{SecureRandom.hex(12)}"
        body = String.new(encoding: Encoding::BINARY)
        params.each do |key, value|
          body << "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{key}\"\r\n\r\n#{value}\r\n"
        end
        safe_name = filename.to_s.gsub(/[^\w.\-]+/, "_")
        body << "--#{boundary}\r\nContent-Disposition: form-data; name=\"source\"; filename=\"#{safe_name}\"\r\n"
        body << "Content-Type: #{content_type}\r\n\r\n"
        body << bytes.b
        body << "\r\n--#{boundary}--\r\n"
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 180
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        request.body = body
        response = http.request(request)
        parse!(Struct.new(:body, :status, :success?).new(response.body, response.code.to_i, response.is_a?(Net::HTTPSuccess)))
      rescue Faraday::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
        raise Error.new(e.message, transient: true)
      end

      def long_lived_user_token(short_token)
        get("/oauth/access_token",
          grant_type: "fb_exchange_token",
          client_id: MetaCredentials.app_id,
          client_secret: MetaCredentials.app_secret,
          fb_exchange_token: short_token).fetch("access_token")
      end

      # Page ids the person ticked for "current Pages only". Those grants do not
      # appear on /me/accounts. The app token is sent as a parameter and is not logged.
      def granted_page_ids(user_token)
        body = get("/debug_token",
          input_token: user_token,
          access_token: "#{MetaCredentials.app_id}|#{MetaCredentials.app_secret}")
        Array(body.dig("data", "granular_scopes"))
          .flat_map { |scope| Array(scope["target_ids"]) }
          .map(&:to_s)
          .uniq
      end

      # Follows paging.next. The next URL contains a token, so it is never logged.
      def get_all(path, params = {})
        results = []
        body = get(path, params)
        loop do
          results.concat(Array(body["data"]))
          next_url = body.dig("paging", "next")
          break if next_url.blank?

          body = parse!(Faraday.get(next_url))
        end
        results
      rescue Faraday::Error => e
        raise Error.new(e.message, transient: true)
      end

      private

      def request(method, path, params)
        conn = Faraday.new(url: HOST) do |f|
          f.request :url_encoded
          f.options.timeout = 60
          f.options.open_timeout = 10
        end
        parse!(conn.public_send(method, "/#{VERSION}#{path}", params))
      rescue Faraday::Error => e
        raise Error.new(e.message, transient: true)
      end

      def parse!(res)
        body = begin
          JSON.parse(res.body.presence || "{}")
        rescue JSON::ParserError
          raise Error.new("Unreadable response (HTTP #{res.status})", http_status: res.status)
        end
        if body["error"] || !res.success?
          e = body["error"] || {}
          raise Error.new(e["message"] || "HTTP #{res.status}",
            code: e["code"], subcode: e["error_subcode"], type: e["type"], http_status: res.status)
        end
        body
      end
    end
  end
end
