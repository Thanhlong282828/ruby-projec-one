module HrmWorkforce
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def employees(actor:, page: 1, search: nil, api: false)
          raise NotImplementedError, "HrmWorkforce::ReadRepositoryInterface##employees"
        end
        def employee!(actor:, id:)
          raise NotImplementedError, "HrmWorkforce::ReadRepositoryInterface##employee!"
        end
        def departments(actor:, page: 1)
          raise NotImplementedError, "HrmWorkforce::ReadRepositoryInterface##departments"
        end
        def department!(actor:, id:)
          raise NotImplementedError, "HrmWorkforce::ReadRepositoryInterface##department!"
        end
        def form_options(actor:)
          raise NotImplementedError, "HrmWorkforce::ReadRepositoryInterface##form_options"
        end
        def employee_for_user!(user:)
          raise NotImplementedError, "HrmWorkforce::ReadRepositoryInterface##employee_for_user!"
        end
        def employee_for_leave!(actor:, id:)
          raise NotImplementedError, "HrmWorkforce::ReadRepositoryInterface##employee_for_leave!"
        end
        def active_employees()
          raise NotImplementedError, "HrmWorkforce::ReadRepositoryInterface##active_employees"
        end
        def employee_count(actor:)
          raise NotImplementedError, "HrmWorkforce::ReadRepositoryInterface##employee_count"
        end
        def department_count()
          raise NotImplementedError, "HrmWorkforce::ReadRepositoryInterface##department_count"
        end
      end
    end
  end
end
