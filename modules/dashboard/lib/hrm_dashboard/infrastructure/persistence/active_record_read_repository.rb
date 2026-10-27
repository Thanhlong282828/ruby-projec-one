module HrmDashboard
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def snapshot(actor:)
          workforce = Hrm::Container.resolve(HrmWorkforce::Domain::Repositories::ReadRepositoryInterface)
          leaves = Hrm::Container.resolve(HrmTimeOff::Domain::Repositories::ReadRepositoryInterface)
          recruitment = Hrm::Container.resolve(HrmRecruitment::Domain::Repositories::ReadRepositoryInterface)
          if actor.staff?
            Rails.cache.fetch("dashboard/stats", expires_in: 2.minutes) do
              { employees: workforce.employee_count(actor: actor), departments: workforce.department_count, pending: leaves.pending_count, candidates: recruitment.count }
            end
          else
            { employees: workforce.employee_count(actor: actor), departments: "—", pending: leaves.pending_count(actor: actor), candidates: "—" }
          end
        end
      end
    end
  end
end
