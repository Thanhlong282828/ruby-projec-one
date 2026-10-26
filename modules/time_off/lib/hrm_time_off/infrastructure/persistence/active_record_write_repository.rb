module HrmTimeOff
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        def build(employee:, attributes:) = employee.leave_requests.new(attributes)
        def create!(employee:, attributes:) = employee.with_lock { employee.leave_requests.create!(attributes) }
        def with_review_lock(request:, &block)
          request.employee.with_lock do
            request.lock!
            block.call
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
