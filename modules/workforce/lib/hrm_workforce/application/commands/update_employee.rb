module HrmWorkforce
  module Application
    module Commands
      class UpdateEmployee < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @repository = repository
        end
        def call(actor:, record:, attributes:)
          authorize!(actor, record, :update?)
          sensitive = %w[salary_cents bank_account national_id]
          raise Pundit::NotAuthorizedError if !actor.allowed?("employees.sensitive") && attributes.keys.any? { |key| sensitive.include?(key.to_s) }
          @repository.update!(record: record, attributes: attributes)
        end
      end
    end
  end
end
