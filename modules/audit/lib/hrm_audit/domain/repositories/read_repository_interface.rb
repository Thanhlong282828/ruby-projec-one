module HrmAudit
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def list(actor:, page: 1)
          raise NotImplementedError, "HrmAudit::ReadRepositoryInterface##list"
        end
      end
    end
  end
end
