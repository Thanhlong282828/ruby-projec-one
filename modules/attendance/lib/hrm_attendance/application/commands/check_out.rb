module HrmAttendance
  module Application
    module Commands
      class CheckOut < Hrm::UseCase
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface), write: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @read, @write = read, write
        end
        def call(actor:, id:, at: Time.current)
          require_actor!(actor)
          record = @read.find!(actor: actor, id: id)
          authorize!(actor, record, :checkout?)
          @write.checkout!(record: record, at: at)
        end
      end
    end
  end
end
