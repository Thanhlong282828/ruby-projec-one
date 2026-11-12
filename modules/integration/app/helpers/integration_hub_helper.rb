module IntegrationHubHelper
  def integration_status_label(status)
    { "received" => "Chờ kiểm tra", "acknowledged" => "Đã xác nhận", "rejected" => "Đã từ chối" }.fetch(status, status)
  end
end
