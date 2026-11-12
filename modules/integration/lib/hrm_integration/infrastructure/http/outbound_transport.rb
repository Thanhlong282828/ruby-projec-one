require "net/http"
require "resolv"
require "ipaddr"
require "timeout"
module HrmIntegration
  module Infrastructure
    module Http
      class OutboundTransport
        class Unavailable < StandardError; end
        PRIVATE_NETWORKS = %w[0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4].map { |cidr| IPAddr.new(cidr) }.freeze
        def self.targets(company_id:)
          parsed = JSON.parse(ENV.fetch("INTEGRATION_TARGETS_JSON", "{}"), max_nesting: 4)
          raise Unavailable unless parsed.is_a?(Hash) && parsed.size <= 50
          valid = parsed.all? do |key, config|
            key.match?(/\A[a-z][a-z0-9_-]{0,39}\z/) && config.is_a?(Hash) && config.keys.sort == %w[company_ids url] &&
              config["url"].is_a?(String) && config["url"].bytesize <= 2048 && config["company_ids"].is_a?(Array) &&
              config["company_ids"].size.between?(1, 100) && config["company_ids"].all? { |id| id.is_a?(Integer) && id.positive? }
          end
          raise Unavailable unless valid
          parsed.select { |_, config| config["company_ids"].include?(company_id) }.transform_values { |config| config["url"] }
        rescue JSON::ParserError
          raise Unavailable
        end
        def self.uri!(url)
          uri = URI.parse(url)
          raise Unavailable unless uri.is_a?(URI::HTTPS) && uri.port == 443 && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
          uri
        rescue URI::InvalidURIError
          raise Unavailable
        end
        def self.public_ip!(address)
          ip = IPAddr.new(address)
          raise Unavailable unless ip.ipv4? && PRIVATE_NETWORKS.none? { |range| range.include?(ip) }
          address
        rescue IPAddr::InvalidAddressError
          raise Unavailable
        end
        def call(company_id:, target_key:, body:, event_id:, secret:)
          Timeout.timeout(10) do
            uri = self.class.uri!(self.class.targets(company_id: company_id).fetch(target_key) { raise Unavailable })
            addresses = Resolv.getaddresses(uri.host)
            raise Unavailable if addresses.empty?
            addresses.each { |address| self.class.public_ip!(address) }
            # Pin validated address while retaining original hostname for TLS/SNI verification.
            http = Net::HTTP.new(uri.host, 443, nil)
            http.ipaddr = addresses.first
            http.max_retries = 0
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            http.open_timeout, http.read_timeout, http.write_timeout = 3, 3, 3
            timestamp = Time.current.to_i.to_s
            request = Net::HTTP::Post.new(uri.request_uri)
            request["Content-Type"] = "application/json"
            request["X-Webhook-Id"] = event_id
            request["X-Webhook-Timestamp"] = timestamp
            request["X-Webhook-Signature"] = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{event_id}.#{body}")
            request.body = body
            code = nil
            http.start do |session|
              session.request(request) do |response|
                code = response.code.to_i
                # Discard bounded response only; never retain remote response or follow redirects.
                size = 0
                response.read_body { |chunk| size += chunk.bytesize; raise Unavailable if size > 4096 }
              end
            end
            { code: code, outcome: code.between?(200, 299) ? "delivered" : "http_error" }
          end
        rescue Unavailable
          { code: nil, outcome: "target_unavailable" }
        rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Resolv::ResolvError
          { code: nil, outcome: "transport_error" }
        end
      end
    end
  end
end
