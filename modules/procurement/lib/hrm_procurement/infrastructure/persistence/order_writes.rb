module HrmProcurement
  module Infrastructure
    module Persistence
      module OrderWrites
        def save_supplier!(actor:, id:, attributes:, lock_version:)
          ::ProcurementSupplier.transaction do
            ActiveRecord::Base.uncached do
              context = WriteAuthorization.lock!(actor)
              record = id ? Pundit.policy_scope!(context, ::ProcurementSupplier).lock.find(Domain::Services::RequestFilters.id(id)) : ::ProcurementSupplier.new(company_id: context.company_id)
              Pundit.authorize(context, record, id ? :update? : :create?)
              order_version!(record, lock_version, "update") if id
              record.assign_attributes(Domain::Services::OrderContent.supplier(attributes))
              Current.set(user: actor) { record.save! }
              record
            end
          end
        end
        def create_order!(actor:, purchase_request_id:, supplier_id:, expected_on:)
          ::PurchaseOrder.transaction do
            ActiveRecord::Base.uncached do
              context = WriteAuthorization.lock!(actor)
              Pundit.authorize(context, ::PurchaseOrder, :create?)
              source = Pundit.policy_scope!(context, ::PurchaseRequest).lock.find(Domain::Services::RequestFilters.id(purchase_request_id))
              Pundit.authorize(context, source, :show?)
              raise Domain::Services::RequestConflict, "Chỉ phiếu đã duyệt được lập PO" unless source.status == "approved"
              # A replay returns the original PO without changing supplier, date or prices.
              existing = ::PurchaseOrder.where(company_id: context.company_id, purchase_request_id: source.id).lock.first
              next existing if existing
              supplier = ::ProcurementSupplier.where(company_id: context.company_id, status: "active").lock.find(Domain::Services::RequestFilters.id(supplier_id))
              record = ::PurchaseOrder.new(company_id: context.company_id, purchase_request: source, supplier: supplier, created_by_id: context.id,
                code: "PO-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}", status: "draft", currency: "VND",
                supplier_code_snapshot: supplier.code, supplier_name_snapshot: supplier.name, request_code_snapshot: source.code,
                title_snapshot: source.title, request_total_snapshot: source.estimated_total, ordered_total: source.estimated_total,
                expected_on: Domain::Services::OrderContent.date(expected_on))
              source.lines.lock.each do |line|
                record.lines.build(company_id: context.company_id, purchase_request_id: source.id, source_line: line, position: line.position,
                  description: line.description, quantity: line.quantity, unit: line.unit, source_unit_price: line.estimated_unit_price, unit_price: line.estimated_unit_price, line_total: line.line_total)
              end
              order_persist!(actor, record, "created")
            end
          end
        end
        def update_order!(actor:, id:, attributes:, lock_version:)
          order_mutate(actor, id, lock_version, :update_any?, "updated") do |record|
            prices = Domain::Services::OrderContent.prices(attributes[:items], record.lines.lock.to_a)
            record.lines.each do |line|
              line.unit_price = prices.fetch(line.source_line_id.to_s)
              line.line_total = (line.quantity * line.unit_price).round(0, BigDecimal::ROUND_HALF_UP)
            end
            record.ordered_total = record.lines.sum(BigDecimal("0"), &:line_total)
            record.expected_on = Domain::Services::OrderContent.date(attributes[:expected_on])
            record.price_change_reason = Domain::Services::OrderContent.reason(attributes[:price_change_reason])
          end
        end
        def issue_order!(actor:, id:, lock_version:)
          order_mutate(actor, id, lock_version, :issue_any?, "issued") do |record|
            supplier = ::ProcurementSupplier.where(id: record.supplier_id, company_id: record.company_id).lock.first!
            raise Domain::Services::RequestContent::Invalid, "Nhà cung cấp đã ngừng hoạt động; không thể phát hành PO" unless supplier.status == "active"
            changed = record.lines.lock.any? { |line| line.unit_price != line.source_unit_price }
            if changed && record.price_change_reason.blank?
              raise Domain::Services::RequestContent::Invalid, "Phải lưu lý do thay đổi giá trước khi phát hành"
            end
            record.status = "issued"
            record.issued_by_id = actor.id
            record.issued_at = Time.current
          end
        end
        private
        def order_version!(record, version, action)
          valid = (version.is_a?(Integer) && version >= 0) || (version.is_a?(String) && /\A\d{1,10}\z/.match?(version))
          raise ActiveRecord::StaleObjectError.new(record, action) unless valid && record.lock_version == version.to_i
        end
        def order_mutate(actor, id, version, permission, action)
          ::PurchaseOrder.transaction do
            ActiveRecord::Base.uncached do
              context = WriteAuthorization.lock!(actor)
              record = Pundit.policy_scope!(context, ::PurchaseOrder).lock.find(Domain::Services::RequestFilters.id(id))
              Pundit.authorize(context, record, permission)
              order_version!(record, version, action)
              raise Domain::Services::RequestConflict, "PO đã phát hành không được sửa" unless record.status == "draft"
              yield record
              record.updated_at = Time.current
              order_persist!(actor, record, action)
            end
          end
        end
        def order_persist!(actor, record, action)
          Current.set(user: actor) do
            record.save!
            ::PurchaseOrderEvent.create!(company_id: record.company_id, purchase_order: record, actor_id: actor.id, action: action, version: record.lock_version, note: record.price_change_reason)
          end
          record
        end
      end
    end
  end
end
