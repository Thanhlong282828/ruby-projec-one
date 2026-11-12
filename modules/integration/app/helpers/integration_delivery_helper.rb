module IntegrationDeliveryHelper
  def delivery_status_label(status)
    { "queued" => "Chờ gửi", "retry_wait" => "Chờ thử lại", "delivered" => "Đã gửi", "dead_letter" => "Cần xử lý (dead-letter)", "blocked" => "Bị chặn" }.fetch(status, status)
  end
end
