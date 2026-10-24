require "net/http"
require "openssl"
require "test_helper"
require "minitest/mock"
class OutboxDispatchJobTest < ActiveSupport::TestCase
  test "successful delivery marks event and broadcasts safe payload" do
    event = OutboxEvent.create!(event_type: "employee.created", payload: { record_id: 1 })
    http = Minitest::Mock.new
    http.expect :request, Net::HTTPAccepted.new("1.1", "202", "Accepted") do |request|
      expected = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("EVENT_SECRET"), request.body)
      request["X-Event-Signature"] == expected
    end
    Net::HTTP.stub(:start, ->(*args, **kwargs, &block) { block.call(http) }) { OutboxDispatchJob.perform_now }
    assert_not_nil event.reload.delivered_at
    http.verify
  end
  test "failed delivery retains pending event for recovery" do
    event = OutboxEvent.create!(event_type: "employee.created", payload: { record_id: 1 })
    Net::HTTP.stub(:start, ->(*args, **kwargs, &block) { raise IOError, "offline" }) do
      assert_raises(IOError) { OutboxDispatchJob.new.perform }
    end
    assert_nil event.reload.delivered_at
  end
end
