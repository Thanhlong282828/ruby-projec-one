module HrmWorkforce
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        def build_employee(attributes:) = ::Employee.new(attributes)
        def build_department(attributes:) = ::Department.new(attributes)
        def save!(record:)
          record.save!
          record
        end
        def update!(record:, attributes:)
          record.update!(attributes)
          record
        end
        def destroy(record:) = record.destroy
        def with_employee_lock(employee:, &block) = employee.with_lock(&block)
      end
    end
  end
end
