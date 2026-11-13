module HrmProcurement
  module Domain
    class PermissionDefinitions
      ORDER_DEFINITIONS = {
        "inventory.return_reversals.read" => "Xem đảo phiếu trả",
        "inventory.return_reversals.post" => "Ghi sổ đảo phiếu trả",
        "inventory.returns.read" => "Xem phiếu trả nhà cung cấp",
        "inventory.returns.post" => "Ghi sổ trả nhà cung cấp",
        "inventory.catalog.read" => "Xem kho và mã hàng",
        "inventory.catalog.manage" => "Quản lý kho và mã hàng",
        "inventory.receipts.read" => "Xem phiếu nhập kho",
        "inventory.receipts.post" => "Ghi sổ nhập kho",
        "inventory.balances.read" => "Xem tồn theo kho",
        "procurement.receipts.read" => "Xem phiếu nhận hàng",
        "procurement.receipts.create" => "Ghi nhận hàng",
        "procurement.suppliers.read" => "Xem nhà cung cấp",
        "procurement.suppliers.create" => "Tạo nhà cung cấp",
        "procurement.suppliers.update" => "Sửa nhà cung cấp",
        "procurement.orders.read" => "Xem đơn mua hàng",
        "procurement.orders.create" => "Lập PO từ phiếu đã duyệt",
        "procurement.orders.update" => "Sửa PO nháp",
        "procurement.orders.issue" => "Phát hành PO"
      }.freeze
      DEFINITIONS = {
        "procurement.requests.read" => "Xem yêu cầu mua của mình",
        "procurement.requests.read_all" => "Xem yêu cầu mua trong công ty",
        "procurement.requests.create" => "Tạo yêu cầu mua",
        "procurement.requests.update" => "Sửa yêu cầu mua nháp của mình",
        "procurement.requests.submit" => "Gửi yêu cầu mua của mình",
        "procurement.requests.review" => "Quyết định yêu cầu mua của người khác"
      }.merge(ORDER_DEFINITIONS).freeze
      def self.for_role(role)
        return DEFINITIONS.keys if %w[admin manager].include?(role)
        return DEFINITIONS.keys - ORDER_DEFINITIONS.keys - %w[procurement.requests.read_all procurement.requests.review] if %w[employee hr].include?(role)
        []
      end
    end
  end
end
