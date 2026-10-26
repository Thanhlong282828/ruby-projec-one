module HrmTimeOff
  module Application
    module Commands
      class SubmitLeave < Hrm::UseCase
        def initialize(write: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface), workforce: Hrm::Container.resolve(HrmWorkforce::Domain::Repositories::ReadRepositoryInterface))
          @write, @workforce = write, workforce
        end
        def call(actor:, employee_id:, attributes:)
          require_actor!(actor)
          employee = @workforce.employee_for_leave!(actor: actor, id: employee_id)
          authorize!(actor, @write.build(employee: employee, attributes: attributes), :create?)
          @write.create!(employee: employee, attributes: attributes)
        end
      end
    end
  end
end
