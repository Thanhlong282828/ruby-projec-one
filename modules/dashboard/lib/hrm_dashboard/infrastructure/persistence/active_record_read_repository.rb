module HrmDashboard
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def snapshot(actor:, period:)
          # Each module owns its scoped predicates; no dashboard-owned cross-engine SQL.
          data = { period: period }
          if Pundit.policy!(actor, ::Employee).index?
            workforce = Hrm::Container.resolve(HrmWorkforce::Domain::Repositories::ReadRepositoryInterface)
            data[:employees] = workforce.employee_count(actor: actor)
          end
          if Pundit.policy!(actor, ::LeaveRequest).index?
            leaves = Hrm::Container.resolve(HrmTimeOff::Domain::Repositories::ReadRepositoryInterface)
            data[:pending] = leaves.pending_count(actor: actor)
            data[:requests] = leaves.list(actor: actor, recent: true, status: "pending")
          end
          if Pundit.policy!(actor, ::Attendance).index?
            attendance = Hrm::Container.resolve(HrmAttendance::Domain::Repositories::ReadRepositoryInterface)
            data[:open] = attendance.count(actor: actor, status: "open")
            data[:attendances] = attendance.list(actor: actor, status: "open", recent: true)
          end
          if Pundit.policy!(actor, ::PayRun).index?
            payroll = Hrm::Container.resolve(HrmPayroll::Domain::Repositories::ReadRepositoryInterface)
            data[:drafts] = payroll.count(actor: actor, period: period, status: "draft")
            data[:runs] = payroll.list(actor: actor, period: period, recent: true)
          end
          if Pundit.policy!(actor, ::OnboardingCase).index?
            onboarding = Hrm::Container.resolve(HrmOnboarding::Domain::Repositories::ReadRepositoryInterface)
            data[:board] = onboarding.board(actor: actor)
          end
          if Pundit.policy!(actor, ::Department).index?
            workforce = Hrm::Container.resolve(HrmWorkforce::Domain::Repositories::ReadRepositoryInterface)
            data[:departments] = workforce.department_count(actor: actor)
          end
          if Pundit.policy!(actor, ::Candidate).index?
            recruitment = Hrm::Container.resolve(HrmRecruitment::Domain::Repositories::ReadRepositoryInterface)
            data[:candidates] = recruitment.count(actor: actor)
          end
          if Pundit.policy!(actor, ::IntegrationWebhook).index?
            integration = Hrm::Container.resolve(HrmIntegration::Domain::Repositories::ReadRepositoryInterface)
            data[:webhooks] = integration.count(actor: actor)
          end
          if Pundit.policy!(actor, ::PurchaseRequest).review_queue?
            procurement = Hrm::Container.resolve(HrmProcurement::Domain::Repositories::ReadRepositoryInterface)
            data[:purchases] = procurement.workspace(actor: actor, filters: { status: "submitted", view: "review", page: 1 }, recent: true)
          end
          if Pundit.policy!(actor, ::PurchaseOrder).create? && Pundit.policy!(actor, ::PurchaseRequest).index?
            procurement = Hrm::Container.resolve(HrmProcurement::Domain::Repositories::ReadRepositoryInterface)
            data[:awaiting_orders] = procurement.workspace(actor: actor, filters: { status: "approved", view: "awaiting_po", page: 1 }, recent: true)
          end
          if Pundit.policy!(actor, ::PurchaseOrder).index?
            procurement = Hrm::Container.resolve(HrmProcurement::Domain::Repositories::ReadRepositoryInterface)
            data[:pending_receipts] = procurement.order_workspace(actor: actor, filters: { delivery: "pending", page: 1 })
          end
          data
        end
      end
    end
  end
end
