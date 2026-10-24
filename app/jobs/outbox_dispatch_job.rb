require "net/http"
require "openssl"
class OutboxDispatchJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 8
  def perform
    OutboxEvent.pending.order(:id).limit(100).each do |event|
      event.with_lock do
        next if event.delivered_at
        body = { id: event.id, type: event.event_type, payload: event.payload }.to_json
        uri = URI(ENV.fetch("EVENT_URL"))
        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        request.body = body
        request["X-Event-Signature"] = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("EVENT_SECRET"), body)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 5) { |http| http.request(request) }
        raise "Event receiver unavailable (#{response.code})" unless response.is_a?(Net::HTTPSuccess)
        ActionCable.server.broadcast("hr_updates", { type: event.event_type, id: event.id })
        LeaveDecisionJob.perform_later(event.payload.fetch("record_id")) if event.event_type == "leave_request.reviewed"
        event.update!(delivered_at: Time.current)
      end
    end
  end
end
