module HrmProcurement
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        include OrderWrites
        def create!(actor:, attributes:)
          ::PurchaseRequest.transaction do
            ActiveRecord::Base.uncached do
              context = WriteAuthorization.lock!(actor)
              Pundit.authorize(context, ::PurchaseRequest, :create?)
              content = Domain::Services::RequestContent.read(attributes)
              record = ::PurchaseRequest.new(company_id: context.company_id, created_by_id: context.id,
                code: "PR-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}", currency: "VND", status: "draft")
              assign_content(record, content)
              persist!(actor, record, "created", nil)
            end
          end
        end
        def update!(actor:, id:, attributes:, lock_version:)
          mutate(actor, id, lock_version, :update_draft?, "updated") do |record|
            raise Domain::Services::RequestConflict, "Chỉ phiếu nháp được sửa" unless record.status == "draft"
            content = Domain::Services::RequestContent.read(attributes)
            # The parent is locked and authorized as draft; replacing rows is atomic.
            ::PurchaseRequestLine.where(company_id: record.company_id, purchase_request_id: record.id).delete_all
            record.lines.reset
            assign_content(record, content)
          end
        end
        def submit!(actor:, id:, lock_version:)
          mutate(actor, id, lock_version, :submit_request?, "submitted") do |record|
            raise Domain::Services::RequestConflict, "Phiếu không còn là bản nháp" unless record.status == "draft"
            raise Domain::Services::RequestConflict, "Phiếu phải có dòng hàng" unless record.lines.lock.exists?
            record.status = "submitted"
            record.submitted_at = Time.current
          end
        end
        def decide!(actor:, id:, decision:, reason:, lock_version:)
          mutate(actor, id, lock_version, :decide?, decision) do |record|
            raise Domain::Services::RequestConflict, "Phiếu không còn chờ duyệt" unless record.status == "submitted"
            unless decision.is_a?(String) && %w[approved rejected].include?(decision)
              raise Domain::Services::RequestContent::Invalid, "Quyết định không hợp lệ"
            end
            record.rejection_reason = decision == "rejected" ? Domain::Services::RequestContent.text(reason, "Lý do từ chối", 2000) : nil
            record.status = decision
            record.reviewed_by_id = actor.id
            record.reviewed_at = Time.current
          end
        end
        private
        def assign_content(record, content)
          record.assign_attributes(content.except(:items))
          content[:items].each_with_index { |item, index| record.lines.build(item.merge(company_id: record.company_id, position: index + 1)) }
        end
        def mutate(actor, id, version, permission, action)
          id = Domain::Services::RequestFilters.id(id)
          ::PurchaseRequest.transaction do
            ActiveRecord::Base.uncached do
              context = WriteAuthorization.lock!(actor)
              record = Pundit.policy_scope!(context, ::PurchaseRequest).lock.find(id)
              Pundit.authorize(context, record, permission)
              valid_version = (version.is_a?(Integer) && version >= 0) || (version.is_a?(String) && /\A\d{1,10}\z/.match?(version))
              raise ActiveRecord::StaleObjectError.new(record, action) unless valid_version && record.lock_version == version.to_i
              previous = record.status
              yield record
              record.updated_at = Time.current
              persist!(actor, record, action, previous)
            end
          end
        end
        def persist!(actor, record, action, previous)
          Current.set(user: actor) do
            record.save!
            ::PurchaseRequestEvent.create!(company_id: record.company_id, purchase_request: record, actor_id: actor.id,
              action: action, from_status: previous, to_status: record.status, version: record.lock_version, note: record.rejection_reason)
          end
          record
        end
      end
    end
  end
end
