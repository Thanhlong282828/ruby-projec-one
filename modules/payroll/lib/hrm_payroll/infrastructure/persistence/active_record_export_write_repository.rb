module HrmPayroll
  module Infrastructure
    module Persistence
      class ActiveRecordExportWriteRepository < Domain::Repositories::ExportWriteRepositoryInterface
        def create!(actor:, pay_run_id:)
          Pundit.authorize(actor, ::PayrollExport, :create?)
          run = Pundit.policy_scope!(actor, ::PayRun).find(Domain::Services::ExportFilters.id!(pay_run_id))
          run.with_lock do
            Pundit.authorize(actor, ::PayrollExport, :create?)
            raise Domain::Services::PayrollCsv::InvalidSource unless run.finalized? && run.finalized_at
            existing = Pundit.policy_scope!(actor, ::PayrollExport).find_by(pay_run_id: run.id)
            return existing if existing
            slips = run.payslips.where(company_id: actor.company_id).order(:id).lock.limit(Domain::Services::PayrollCsv::MAX_ROWS + 1).to_a
            raise Domain::Services::PayrollCsv::InvalidSource unless slips.size.between?(1, Domain::Services::PayrollCsv::MAX_ROWS)
            raise Domain::Services::PayrollCsv::InvalidSource if slips.any? { |slip| slip.employee_code_snapshot.blank? }
            rows = slips.map { |slip| { employee_code: slip.employee_code_snapshot, gross_cents: slip.gross_cents, deductions_cents: slip.deductions_cents, net_cents: slip.net_cents } }
            uuid = SecureRandom.uuid
            artifact = Domain::Services::PayrollCsv.build(public_id: uuid, period: run.period, rows: rows)
            Current.set(user: actor) do
              ::PayrollExport.create!(company_id: actor.company_id, pay_run: run, created_by: actor, public_id: uuid, period: run.period,
                artifact: artifact[:bytes], checksum: artifact[:checksum], byte_size: artifact[:byte_size], employee_count: artifact[:employee_count])
            end
          end
        end
        def download!(actor:, id:)
          Pundit.authorize(actor, ::PayrollExport, :download?)
          record = Pundit.policy_scope!(actor, ::PayrollExport).find(Domain::Services::ExportFilters.id!(id))
          failure, bytes = nil, nil
          record.with_lock do
            Pundit.authorize(actor, record, :download?)
            begin
              raise Domain::Services::PayrollCsv::IntegrityError unless record.format == "payroll_csv_v1" && record.version == 1
              bytes = Domain::Services::PayrollCsv.verify!(bytes: record.artifact, checksum: record.checksum, byte_size: record.byte_size,
                employee_count: record.employee_count, public_id: record.public_id, period: record.period)
            rescue Domain::Services::PayrollCsv::IntegrityError, ActiveRecord::Encryption::Errors::Decryption
              failure = Domain::Services::PayrollCsv::IntegrityError.new
            end
            Current.set(user: actor) do
              record.payroll_export_accesses.create!(company_id: actor.company_id, actor: actor, result: failure ? "integrity_failed" : "allowed")
            end
          end
          raise failure if failure
          { bytes: bytes, filename: record.filename }
        end
      end
    end
  end
end
