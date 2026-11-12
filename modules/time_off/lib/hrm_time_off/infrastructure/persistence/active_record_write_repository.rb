module HrmTimeOff
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        def build(employee:, attributes:) = employee.leave_requests.new(attributes.merge(company_id: employee.company_id))
        def create!(employee:, attributes:) = employee.with_lock { employee.leave_requests.create!(attributes) }
        def with_review_lock(request:, &block)
          employee = request.employee
          employee.with_lock do
            request.lock!
            raise ActiveRecord::StaleObjectError.new(request, "review") unless request.employee_id == employee.id
            request.association(:employee).target = employee
            ActiveRecord::Base.uncached { yield }
          end
        end
        def review!(request:, reviewer:, decision:)
          request.update!(status: decision, reviewer: reviewer, reviewed_at: Time.current)
          request
        end
      end
    end
  end
end
