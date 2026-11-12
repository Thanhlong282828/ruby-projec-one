module IntegrationAuditHelper
  def integration_audit_url(filters, changes = {})
    "/integration/audit?#{filters.merge(changes).compact.to_query}"
  end
  def integration_audit_resource(type)
    { "IntegrationConnection" => "Kết nối", "IntegrationWebhook" => "Sự kiện nhận",
      "IntegrationDelivery" => "Yêu cầu gửi", "IntegrationDeliveryAttempt" => "Lần thử gửi" }.fetch(type, "Bản ghi tích hợp")
  end
  def integration_audit_action(action)
    { "created" => "Tạo mới", "updated" => "Cập nhật", "deleted" => "Xóa" }.fetch(action, "Thay đổi")
  end
end
