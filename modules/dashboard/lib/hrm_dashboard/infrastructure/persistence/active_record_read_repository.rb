module HrmDashboard
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def snapshot(actor:)
          workforce = Hrm::Container.resolve(HrmWorkforce::Domain::Repositories::ReadRepositoryInterface)
          leaves = Hrm::Container.resolve(HrmTimeOff::Domain::Repositories::ReadRepositoryInterface)
          recruitment = Hrm::Container.resolve(HrmRecruitment::Domain::Repositories::ReadRepositoryInterface)
          # User + persisted permission digest prevent cached stats from outliving revocation.
          digest = Digest::SHA256.hexdigest(actor.effective_permission_keys.sort.join("|"))
          Rails.cache.fetch(["dashboard", actor.company_id, actor.id, digest], expires_in: 30.seconds) do
            { employees: workforce.employee_count(actor: actor), departments: workforce.department_count(actor: actor), pending: leaves.pending_count(actor: actor), candidates: recruitment.count(actor: actor) }
          end
        end
      end
    end
  end
end
