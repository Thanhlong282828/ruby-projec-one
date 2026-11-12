module HrmOnboarding
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def count(actor:)
          raise NotImplementedError
        end
        def board(actor:)
          raise NotImplementedError
        end
        def find!(actor:, id:)
          raise NotImplementedError
        end
        def employee_options(actor:)
          raise NotImplementedError
        end
      end
    end
  end
end
