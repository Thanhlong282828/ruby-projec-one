module HrmProcurement
  module Providers
    class ProcurementServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmProcurement::Domain::Repositories::ReadRepositoryInterface", "HrmProcurement::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmProcurement::Domain::Repositories::WriteRepositoryInterface", "HrmProcurement::Infrastructure::Persistence::ActiveRecordWriteRepository"
        catalogs = Array(Rails.application.config.x.hrm.permission_catalogs)
        Rails.application.config.x.hrm.permission_catalogs = catalogs | [ "HrmProcurement::Domain::PermissionDefinitions" ]
        permissions = Rails.application.config.x.hrm.realtime_permissions || {}
        Rails.application.config.x.hrm.realtime_permissions = permissions.merge("stock_return_reversal." => "inventory.return_reversals.read", "stock_return." => "inventory.returns.read", "warehouse." => "inventory.catalog.read", "stock_item." => "inventory.catalog.read", "stock_receipt." => "inventory.receipts.read", "goods_receipt." => "procurement.receipts.read", "purchase_request." => "procurement.requests.read_all", "purchase_order." => "procurement.orders.read", "procurement_supplier." => "procurement.suppliers.read")
      end
    end
  end
end
