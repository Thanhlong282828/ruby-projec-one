module HrmProcurement
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        include OrderReads
        include ReceiptReads
        include StockReads
        def workspace(actor:, filters:, recent: false)
          scope = Pundit.policy_scope!(actor, ::PurchaseRequest)
          if filters[:view] == "awaiting_po"
            Pundit.authorize(actor, ::PurchaseOrder, :create?)
            scope = scope.where(status: "approved").where.not(id: ::PurchaseOrder.where(company_id: actor.company_id).select(:purchase_request_id))
          elsif filters[:view] == "review"
            Pundit.authorize(actor, ::PurchaseRequest, :review_queue?)
            scope = scope.where(status: "submitted").where.not(created_by_id: actor.id)
          elsif filters[:view] == "mine"
            scope = scope.where(created_by_id: actor.id)
          end
          scope = scope.where(status: filters[:status]) if filters[:status]
          if filters[:q].present?
            term = "%#{::PurchaseRequest.sanitize_sql_like(filters[:q])}%"
            scope = scope.where("code LIKE ? OR title LIKE ?", term, term)
          end
          count = scope.count
          scope = scope.order(created_at: :desc, id: :desc)
          records = recent ? scope.limit(5).to_a : Hrm::Pagination.call(scope, filters[:page]).to_a
          { count: count, records: records, filters: filters }
        end
        def find!(actor:, id:, history_page: 1)
          record = Pundit.policy_scope!(actor, ::PurchaseRequest).includes(:lines).find(Domain::Services::RequestFilters.id(id))
          Pundit.authorize(actor, record, :show?)
          page = Domain::Services::RequestFilters.page_number(history_page)
          events = record.events.order(version: :desc).limit(26).offset((page - 1) * 25).to_a
          order_access = Pundit.policy!(actor, ::PurchaseOrder)
          order = order_access.index? ? Pundit.policy_scope!(actor, ::PurchaseOrder).find_by(purchase_request_id: record.id) : nil
          { record: record, events: events.first(25), history_page: page, more_history: events.length > 25,
            order: order, can_create_order: order_access.create? && record.status == "approved" && order.nil? }
        end
      end
    end
  end
end
