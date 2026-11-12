module HrmIntegration
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def workspace(actor:, page: 1, status: nil)
          raise NotImplementedError
        end
        def connection!(actor:, id:)
          raise NotImplementedError
        end
        def webhook!(actor:, id:)
          raise NotImplementedError
        end
        def payload!(actor:, id:)
          raise NotImplementedError
        end
        def count(actor:)
          raise NotImplementedError
        end
      end
    end
  end
end
