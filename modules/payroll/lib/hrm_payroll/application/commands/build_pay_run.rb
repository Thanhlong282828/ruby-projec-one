module HrmPayroll
  module Application
    module Commands
      class BuildPayRun < Hrm::UseCase
        def initialize(write: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface), workforce: Hrm::Container.resolve(HrmWorkforce::Domain::Repositories::ReadRepositoryInterface))
          @write, @workforce = write, workforce
        end
        def call(period:, actor:)
          authorize!(actor, ::PayRun, :create?)
          @write.transaction do
            run = @write.create_run!(period: period, actor: actor)
            @workforce.active_employees.each { |employee| @write.create_payslip!(run: run, employee: employee) }
            run
          end
        end
      end
    end
  end
end
