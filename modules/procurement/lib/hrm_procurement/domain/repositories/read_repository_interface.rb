module HrmProcurement
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def workspace(actor:, filters:, recent: false) = raise(NotImplementedError)
        def find!(actor:, id:, history_page: 1) = raise(NotImplementedError)
      end
    end
  end
end
