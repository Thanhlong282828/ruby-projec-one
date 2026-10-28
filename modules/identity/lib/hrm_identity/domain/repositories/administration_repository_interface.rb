module HrmIdentity
  module Domain
    module Repositories
      class AdministrationRepositoryInterface
        def snapshot(actor:, area:, id: nil) = raise(NotImplementedError)
        def update_company!(actor:, attributes:) = raise(NotImplementedError)
        def update_account!(actor:, id:, attributes:) = raise(NotImplementedError)
        def update_role!(actor:, id:, attributes:) = raise(NotImplementedError)
        def create_company!(code:, name:, owner_email:, password:) = raise(NotImplementedError)
        def company_id_for_code!(code:) = raise(NotImplementedError)
        def active_companies = raise(NotImplementedError)
      end
    end
  end
end
