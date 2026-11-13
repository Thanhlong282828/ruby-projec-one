module HrmProcurement
  module Infrastructure
    module Persistence
      module OrderReads
        def supplier_workspace(actor:, filters:)
          scope = Pundit.policy_scope!(actor, ::ProcurementSupplier)
          scoped_workspace(scope, filters, code: "code", title: "name")
        end
        def find_supplier!(actor:, id:)
          Pundit.policy_scope!(actor, ::ProcurementSupplier).find(Domain::Services::RequestFilters.id(id))
        end
        def order_workspace(actor:, filters:)
          scope = Pundit.policy_scope!(actor, ::PurchaseOrder)
          scope = receiving_pending(scope) if filters[:delivery] == "pending"
          workspace = scoped_workspace(scope.includes(:lines), filters, code: "code", title: "title_snapshot")
          quantities = receiving_quantities(workspace[:records])
          workspace[:progress] = workspace[:records].to_h { |record| [ record.id, receiving_progress(record, quantities) ] }
          workspace
        end
        def find_order!(actor:, id:, history_page: nil)
          record = Pundit.policy_scope!(actor, ::PurchaseOrder).includes(:lines, :purchase_request).find(Domain::Services::RequestFilters.id(id))
          Pundit.authorize(actor, record, :show?)
          page = Domain::Services::RequestFilters.page_number(history_page)
          events = record.events.order(version: :desc).limit(26).offset((page - 1) * 25).to_a
          quantities = receiving_quantities([ record ])
          receipts = Pundit.policy_scope!(actor, ::GoodsReceipt).where(purchase_order_id: record.id).order(id: :desc).limit(5).to_a
          { record: record, quantities: quantities, progress: receiving_progress(record, quantities), receipts: receipts, events: events.first(25), history_page: page, more_history: events.size > 25,
            source_visible: Pundit.policy!(actor, record.purchase_request).show? }
        end
        def order_source(actor:, id:)
          Pundit.authorize(actor, ::PurchaseOrder, :create?)
          record = Pundit.policy_scope!(actor, ::PurchaseRequest).includes(:lines).find(Domain::Services::RequestFilters.id(id))
          Pundit.authorize(actor, record, :show?)
          raise Domain::Services::RequestConflict, "Chỉ phiếu đã duyệt được lập PO" unless record.status == "approved"
          { record: record, order: Pundit.policy_scope!(actor, ::PurchaseOrder).find_by(purchase_request_id: record.id),
            suppliers: ::ProcurementSupplier.where(company_id: actor.company_id, status: "active").order(:name, :id).pluck(:name, :code, :id) }
        end
        private
        def scoped_workspace(scope, filters, code:, title:)
          scope = scope.where(status: filters[:status]) if filters[:status]
          if filters[:q].present?
            term = "%#{scope.klass.sanitize_sql_like(filters[:q])}%"
            columns = scope.klass.arel_table # Column names are fixed caller literals.
            scope = scope.where(columns[code].matches(term).or(columns[title].matches(term)))
          end
          { count: scope.count, records: Hrm::Pagination.call(scope.order(created_at: :desc, id: :desc), filters[:page]).to_a, filters: filters }
        end
      end
    end
  end
end
