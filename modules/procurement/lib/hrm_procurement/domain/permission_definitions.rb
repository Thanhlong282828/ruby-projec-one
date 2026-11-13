module HrmProcurement
  module Domain
    class PermissionDefinitions
      DEFINITIONS = {
        "procurement.requests.read" => "Xem yêu cầu mua của mình",
        "procurement.requests.read_all" => "Xem yêu cầu mua trong công ty",
        "procurement.requests.create" => "Tạo yêu cầu mua",
        "procurement.requests.update" => "Sửa yêu cầu mua nháp của mình",
        "procurement.requests.submit" => "Gửi yêu cầu mua của mình",
        "procurement.requests.review" => "Quyết định yêu cầu mua của người khác"
      }.freeze
      def self.for_role(role)
        return DEFINITIONS.keys if %w[admin manager].include?(role)
        return DEFINITIONS.keys - %w[procurement.requests.read_all procurement.requests.review] if %w[employee hr].include?(role)
        []
      end
    end
  end
end
