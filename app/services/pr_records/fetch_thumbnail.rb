require "net/http"
require "ipaddr"
require "resolv"

module PrRecords
  # Reads a page and returns its thumbnail URL. The image file is not downloaded or stored.
  class FetchThumbnail
    class Error < StandardError; end

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 8
    MAX_BYTES = 512 * 1024

    def self.call(raw_url)
      new(raw_url).call
    end

    def self.parse(html, base_url)
      image = extract_image(html.to_s)
      return if image.blank?

      absolute(image, base_url)
    end

    def self.extract_image(html)
      patterns = [
        /<meta[^>]+property=["']og:image(?::secure_url)?["'][^>]+content=["']([^"']+)["']/i,
        /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image(?::secure_url)?["']/i,
        /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i,
        /<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image["']/i
      ]
      patterns.each do |pattern|
        found = html[pattern, 1]
        return found if found.present?
      end
      nil
    end

    def self.absolute(image, base_url)
      return image if image.match?(/\Ahttps?:/i)

      URI.join(base_url, image).to_s
    rescue URI::InvalidURIError
      nil
    end

    def initialize(raw_url)
      @raw_url = raw_url.to_s.strip
    end

    def call
      uri = parse_public_http!(@raw_url)
      html = get(uri)
      image = self.class.parse(html, uri.to_s)
      raise Error, "This page has no thumbnail." if image.blank?

      image
    end

    private

    def parse_public_http!(value)
      uri = URI.parse(value)
      raise Error, "Enter an http or https link." unless uri.is_a?(URI::HTTP) && uri.host.present?
      raise Error, "That link cannot be checked." unless public_host?(uri)

      uri
    rescue URI::InvalidURIError
      raise Error, "Enter a valid link."
    end

    def public_host?(uri)
      addresses = Resolv.getaddresses(uri.host)
      raise Error, "That link cannot be checked." if addresses.empty?

      addresses.none? { |address| private_address?(address) }
    rescue Resolv::ResolvError
      raise Error, "That link cannot be checked."
    end

    def private_address?(address)
      ip = IPAddr.new(address)
      ip.loopback? || ip.private? || ip.link_local?
    rescue IPAddr::InvalidAddressError
      true
    end

    def get(uri, redirects = 0)
      raise Error, "This page has no thumbnail." if redirects > 3

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
      if response.is_a?(Net::HTTPRedirection) && response["location"].present?
        return get(parse_public_http!(response["location"]), redirects + 1)
      end
      raise Error, "This page has no thumbnail." unless response.is_a?(Net::HTTPSuccess)

      response.body.to_s.byteslice(0, MAX_BYTES).to_s
    rescue Error
      raise
    rescue StandardError
      raise Error, "This page has no thumbnail."
    end
  end
end
