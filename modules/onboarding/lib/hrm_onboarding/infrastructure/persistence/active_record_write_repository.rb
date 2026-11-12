module HrmOnboarding
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        TEMPLATE = [
          { "code" => "welcome", "title" => "Giới thiệu công ty và người hướng dẫn", "required" => true, "done" => false },
          { "code" => "documents", "title" => "Kiểm tra hồ sơ tiếp nhận", "required" => true, "done" => false },
          { "code" => "security", "title" => "Hướng dẫn bảo mật và quyền truy cập", "required" => true, "done" => false }
        ].freeze
        def create!(actor:, attributes:)
          employee_id = attributes[:employee_id]
          raise ActiveRecord::RecordNotFound unless (employee_id.is_a?(String) && /\A[1-9]\d{0,17}\z/.match?(employee_id)) || (employee_id.is_a?(Integer) && employee_id.positive?)
          employee = Pundit.policy_scope!(actor, ::Employee).find(employee_id)
          employee.with_lock do
            record = ::OnboardingCase.new(company_id: actor.company_id, employee: employee, start_date: attributes[:start_date], checklist: TEMPLATE.deep_dup)
            Pundit.authorize(actor, record, :create?)
            Current.set(user: actor) { record.save! }
            record
          end
        end
        def transition!(actor:, id:, status:, lock_version:)
          mutate(actor, id, lock_version) do |record|
            invalid!(record, "Chuyển trạng thái không hợp lệ") unless Domain::Services::CaseStateMachine.allowed?(record.status, status)
            if status == "completed" && record.checklist.any? { |item| item["required"] && !item["done"] }
              invalid!(record, "Phải hoàn tất checklist bắt buộc trước khi kết thúc")
            end
            record.status = status
          end
        end
        def complete!(actor:, id:, code:, lock_version:)
          mutate(actor, id, lock_version) do |record|
            invalid!(record, "Hồ sơ đã đóng") if %w[completed cancelled].include?(record.status)
            items = record.checklist.deep_dup
            item = items.find { |entry| entry["code"] == code }
            invalid!(record, "Không tìm thấy checklist") unless item
            item["done"] = true
            record.checklist = items
          end
        end
        private
        def mutate(actor, id, version)
          record = ActiveRecordReadRepository.new.find!(actor: actor, id: id)
          record.with_lock do
            Pundit.authorize(actor, record, :update?)
            valid_version = (version.is_a?(Integer) && version >= 0) || (version.is_a?(String) && /\A\d{1,10}\z/.match?(version))
            raise ActiveRecord::StaleObjectError.new(record, "update") unless valid_version && record.lock_version == version.to_i
            yield record
            Current.set(user: actor) { record.save! }
            record
          end
        end
        def invalid!(record, message)
          record.errors.add(:base, message)
          raise ActiveRecord::RecordInvalid, record
        end
      end
    end
  end
end
