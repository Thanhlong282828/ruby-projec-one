module HrmPayroll
  module Domain
    module Repositories
      class ExportSourceRepositoryInterface
        # Trusted worker/repository entrypoint: call inside its transaction before
        # any consistent grant read; no source bytes/metadata are returned.
        def lock_for_delivery!(company_id:, id:)
          raise NotImplementedError
        end
        def with_verified_descriptor(actor:, id:)
          raise NotImplementedError
        end
      end
    end
  end
end
