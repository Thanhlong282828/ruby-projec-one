module HrmIntegration
  module Domain
    class PermissionDefinitions
      DEFINITIONS = {
        "integration.audit.read" => "Xem nhật ký tích hợp trong company",
        "integration.send" => "Xếp hàng gửi webhook company",
        "integration.retry" => "Retry và replay webhook company",
        "integration.read" => "Xem kết nối và metadata webhook company",
        "integration.create" => "Tạo kết nối webhook",
        "integration.manage" => "Bật/tắt kết nối và đổi khóa webhook",
        "integration.review" => "Xác nhận hoặc từ chối sự kiện nhận",
        "integration.payload.read" => "Xem nội dung webhook nhạy cảm"
      }.freeze
      def self.for_role(role) = role == "admin" ? DEFINITIONS.keys : []
    end
  end
end
