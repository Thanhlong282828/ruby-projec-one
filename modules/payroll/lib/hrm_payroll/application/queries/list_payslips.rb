module HrmPayroll
  module Application
    module Queries
      class ListPayslips < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(actor:, run:)
          authorize!(actor, run, :show?)
          @repository.payslips(run: run)
        end
      end
    end
  end
end
