module HrmAudit
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def append!(actor:, action:, record:, changed_fields:)
          raise NotImplementedError, "HrmAudit::WriteRepositoryInterface##append!"
        end
      end
    end
  end
end
