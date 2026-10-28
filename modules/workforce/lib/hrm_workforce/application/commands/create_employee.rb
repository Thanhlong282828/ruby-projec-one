module HrmWorkforce
  module Application
    module Commands
      class CreateEmployee < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @repository = repository
        end
        def call(actor:, attributes:)
          require_actor!(actor)
          record = @repository.build_employee(attributes: attributes.except(:company_id, "company_id").merge(company_id: actor.company_id))
          authorize!(actor, record, :create?)
          sensitive = %w[salary_cents bank_account national_id]
          raise Pundit::NotAuthorizedError if !actor.allowed?("employees.sensitive") && attributes.keys.any? { |key| sensitive.include?(key.to_s) }
          @repository.save!(record: record)
        end
      end
    end
  end
end
