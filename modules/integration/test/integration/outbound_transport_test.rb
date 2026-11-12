require "test_helper"
require "minitest/mock"
class OutboundTransportTest < ActiveSupport::TestCase
  def transport = HrmIntegration::Infrastructure::Http::OutboundTransport
  test "operator targets are company allowlisted and malformed definitions fail closed" do
    previous = ENV["INTEGRATION_TARGETS_JSON"]
    ENV["INTEGRATION_TARGETS_JSON"] = { partner: { url: "https://example.com/hook", company_ids: [ 1 ] } }.to_json
    assert_equal({ "partner" => "https://example.com/hook" }, transport.targets(company_id: 1))
    assert_equal({}, transport.targets(company_id: 2))
    [ "[]", "{bad", { partner: "https://example.com" }.to_json, { partner: { url: "https://example.com", company_ids: [ "1" ] } }.to_json ].each do |value|
      ENV["INTEGRATION_TARGETS_JSON"] = value
      assert_raises(transport::Unavailable) { transport.targets(company_id: 1) }
    end
  ensure
    ENV["INTEGRATION_TARGETS_JSON"] = previous
  end
  test "only public IPv4 allowed and every private reserved or IPv6 address is rejected" do
    %w[0.0.0.0 10.1.2.3 127.0.0.1 169.254.169.254 172.16.0.1 192.168.1.1 100.100.100.200 198.18.0.1 224.0.0.1 255.255.255.255 ::1 ::ffff:127.0.0.1 fe80::1 invalid].each do |address|
      assert_raises(transport::Unavailable) { transport.public_ip!(address) }
    end
    assert_equal "8.8.8.8", transport.public_ip!("8.8.8.8")
  end
  test "only HTTPS port 443 without embedded secret query fragment allowed" do
    %w[http://example.com ftp://example.com https://example.com:444/hook https://user:pass@example.com/hook https://example.com/hook?secret=x https://example.com/hook#fragment].each do |url|
      assert_raises(transport::Unavailable) { transport.uri!(url) }
    end
    assert_equal "/hook", transport.uri!("https://example.com/hook").path
  end
  test "DNS answers are all checked before connection with no private address fallback" do
    transport.stub(:targets, { "partner" => "https://example.com/hook" }) do
      Resolv.stub(:getaddresses, [ "8.8.8.8", "127.0.0.1" ]) do
        Net::HTTP.stub(:new, ->(*) { flunk "No network connection allowed" }) do
          result = transport.new.call(company_id: 1, target_key: "partner", body: "{}", event_id: "event-1", secret: "key")
          assert_equal "target_unavailable", result[:outcome]
        end
      end
    end
  end
  test "validated address pinned proxy disabled TLS verified and signature bound to raw body" do
    fake = Object.new
    singleton = class << fake; self; end
    singleton.class_eval { attr_accessor :ipaddr, :use_ssl, :verify_mode, :open_timeout, :read_timeout, :write_timeout, :max_retries, :request_seen }
    def fake.start
      yield self
    end
    def fake.request(request)
      self.request_seen = request
      response = Object.new
      def response.code = "302"
      def response.read_body
        yield "redirect ignored"
      end
      yield response
    end
    builder = ->(host, port, proxy) { assert_equal "example.com", host; assert_equal 443, port; assert_nil proxy; fake }
    transport.stub(:targets, { "partner" => "https://example.com/hook" }) do
      Resolv.stub(:getaddresses, [ "8.8.8.8" ]) do
        Net::HTTP.stub(:new, builder) do
          result = transport.new.call(company_id: 1, target_key: "partner", body: "{private}", event_id: "event-1", secret: "key")
          assert_equal({ code: 302, outcome: "http_error" }, result)
        end
      end
    end
    assert_equal "8.8.8.8", fake.ipaddr
    assert_equal true, fake.use_ssl
    assert_equal OpenSSL::SSL::VERIFY_PEER, fake.verify_mode
    request = fake.request_seen
    timestamp = request["X-Webhook-Timestamp"]
    assert_equal "event-1", request["X-Webhook-Id"]
    assert_equal OpenSSL::HMAC.hexdigest("SHA256", "key", "#{timestamp}.event-1.{private}"), request["X-Webhook-Signature"]
  end
end
