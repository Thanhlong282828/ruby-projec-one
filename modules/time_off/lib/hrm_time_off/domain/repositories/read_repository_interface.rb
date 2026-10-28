module HrmTimeOff
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def list(actor:, page: 1, recent: false)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##list"
        end
        def find!(actor:, id:)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##find!"
        end
        def employee_options(actor:)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##employee_options"
        end
        def used_days(employee:, year:)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##used_days"
        end
        def pending_count(actor: nil, company_id: nil)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##pending_count"
        end
        def find_for_mail!(id:, company_id:)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##find_for_mail!"
        end
      end
    end
  end
end
