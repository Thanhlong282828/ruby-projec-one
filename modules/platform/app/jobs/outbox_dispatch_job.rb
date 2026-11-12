require "net/http" # net/http: Thư viện Ruby dùng để gửi HTTP Request.
require "openssl" #  openssl: Cung cấp các chức năng mật mã, trong đó có HMAC-SHA256.
# Tương tự PHP: use Illuminate\Support\Facades\Http;   |  Và hàm: hash_hmac('sha256', $body, $secret);
class OutboxDispatchJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 8
  def perform
    repository = Hrm::Container.resolve(HrmPlatform::Domain::Repositories::OutboxRepositoryInterface)
    repository.pending.each do |event|
      repository.deliver(event: event) do
        body = { id: event.id, company_id: event.company_id, type: event.event_type, payload: event.payload }.to_json
        uri = URI(ENV.fetch("EVENT_URL"))
        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        request.body = body
        timestamp = Time.current.to_i.to_s
        request["X-Event-Timestamp"] = timestamp
        request["X-Event-Signature"] = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("EVENT_SECRET"), "#{timestamp}.#{body}")
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 5, write_timeout: 5) { |http| http.request(request) }
        raise "Event receiver unavailable (#{response.code})" unless response.is_a?(Net::HTTPSuccess)
        ActionCable.server.broadcast("company_#{event.company_id}_hr_updates", { type: event.event_type, id: event.id })
        LeaveDecisionJob.perform_later(event.payload.fetch("record_id"), event.company_id) if event.event_type == "leave_request.reviewed"
      end
    end
  end
end

# Đoạn code này là Background Job xử lý Transactional Outbox Pattern trong Ruby on Rails.
# Đây là một phần Backend khá quan trọng trong hệ thống HRM, kết hợp nhiều kỹ thuật:

# Outbox Pattern + Repository Pattern + Dependency Injection + HTTP Webhook + HMAC-SHA256 + Retry + Action Cable Realtime + Background Job Chaining.

# Mục tiêu là lấy những sự kiện nghiệp vụ đã được lưu trong Outbox,
#  gửi đến hệ thống bên ngoài, sau đó phát thông báo Realtime và kích hoạt Job tiếp theo khi cần.


# 1. Luồng hoạt động tổng thể
# OutboxDispatchJob.perform
# Sidekiq Worker thực thi Job
#      v
# Resolve OutboxRepository
# Lấy repository qua DI Container
#      v
# repository.pending
# Lấy các sự kiện chưa được gửi thành công
#      v
# HTTP POST + HMAC Signature
# Gửi JSON đến EVENT_URL
#  v                            v
# Thất bại                         HTTP 2xx
# Raise Exception → Retry          #Broadcast Realtime và xử lý Job liên quan
