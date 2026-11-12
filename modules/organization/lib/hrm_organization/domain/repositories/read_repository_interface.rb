module HrmOrganization
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def branches(actor:, q: nil, status: nil, after: nil) = raise(NotImplementedError)
        def list(actor:, resource:, page: 1) = raise(NotImplementedError)
        def find!(actor:, resource:, id:) = raise(NotImplementedError)
        def describe(actor:, resource:, record:) = raise(NotImplementedError)
        def form(actor:, resource:, id: nil) = raise(NotImplementedError)
        def tree(actor:) = raise(NotImplementedError)
        def headcount(actor:, on:) = raise(NotImplementedError)
        def export(actor:, resource:) = raise(NotImplementedError)
      end
    end
  end
end
