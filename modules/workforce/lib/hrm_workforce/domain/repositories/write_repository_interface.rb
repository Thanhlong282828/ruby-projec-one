module HrmWorkforce
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def build_employee(attributes:)
          raise NotImplementedError, "HrmWorkforce::WriteRepositoryInterface##build_employee"
        end
        def build_department(attributes:)
          raise NotImplementedError, "HrmWorkforce::WriteRepositoryInterface##build_department"
        end
        def save!(record:)
          raise NotImplementedError, "HrmWorkforce::WriteRepositoryInterface##save!"
        end
        def update!(record:, attributes:)
          raise NotImplementedError, "HrmWorkforce::WriteRepositoryInterface##update!"
        end
        def destroy(record:)
          raise NotImplementedError, "HrmWorkforce::WriteRepositoryInterface##destroy"
        end
        def with_employee_lock(employee:, &block)
          raise NotImplementedError, "HrmWorkforce::WriteRepositoryInterface##with_employee_lock"
        end
      end
    end
  end
end
