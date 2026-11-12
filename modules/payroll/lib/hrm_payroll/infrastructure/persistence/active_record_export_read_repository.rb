module HrmPayroll
  module Infrastructure
    module Persistence
      class ActiveRecordExportReadRepository < Domain::Repositories::ExportReadRepositoryInterface
        def workspace(actor:, before: nil, period: nil)
          Pundit.authorize(actor, ::PayrollExport, :index?)
          before = before.nil? || before == "" ? nil : Domain::Services::ExportFilters.id!(before)
          period = Domain::Services::ExportFilters.period!(period)
          scope = Pundit.policy_scope!(actor, ::PayrollExport)
          scope = scope.where(period: period) if period
          count = scope.count
          scope = scope.where(id: ...before) if before
          rows = scope.select(*::PayrollExport::METADATA_COLUMNS).order(id: :desc).limit(26).to_a
          runs = if Pundit.policy!(actor, ::PayrollExport).create?
            Pundit.policy_scope!(actor, ::PayRun).where(status: "finalized").where.not(id: ::PayrollExport.where(company_id: actor.company_id).select(:pay_run_id))
              .order(period: :desc).limit(100).pluck(:id, :period)
          else
            []
          end
          { records: rows.first(25), count: count, before: before, period: period&.strftime("%Y-%m"),
           next_before: rows.size > 25 ? rows[24].id : nil, eligible_runs: runs }
        end
        def find!(actor:, id:)
          record = Pundit.policy_scope!(actor, ::PayrollExport).select(*::PayrollExport::METADATA_COLUMNS).find(Domain::Services::ExportFilters.id!(id))
          Pundit.authorize(actor, record, :show?)
          { record: record, accesses: record.payroll_export_accesses.where(company_id: actor.company_id).order(id: :desc).limit(25).to_a }
        end
      end
    end
  end
end
