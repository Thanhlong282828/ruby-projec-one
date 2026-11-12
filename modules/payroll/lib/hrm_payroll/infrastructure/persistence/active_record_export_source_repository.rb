module HrmPayroll
  module Infrastructure
    module Persistence
      class ActiveRecordExportSourceRepository < Domain::Repositories::ExportSourceRepositoryInterface
        def lock_for_delivery!(company_id:, id:)
          ::PayrollExport.where(company_id: company_id).lock.find(Domain::Services::ExportFilters.id!(id))
          nil
        end
        def with_verified_descriptor(actor:, id:)
          record = ::PayrollExport.where(company_id: actor.company_id).lock.find(Domain::Services::ExportFilters.id!(id))
          record.with_lock do
            ActiveRecord::Base.uncached { Pundit.authorize(actor, record, :notify?) }
            raise Domain::Services::PayrollCsv::IntegrityError unless record.format == "payroll_csv_v1" && record.version == 1
            Domain::Services::PayrollCsv.verify!(bytes: record.artifact, checksum: record.checksum, byte_size: record.byte_size,
              employee_count: record.employee_count, public_id: record.public_id, period: record.period)
            yield({ source: "payroll_export", source_uuid: record.public_id, version: record.version, format: record.format,
              period: record.period.strftime("%Y-%m"), mime: "text/csv", byte_size: record.byte_size, checksum: record.checksum })
          end
        rescue ActiveRecord::Encryption::Errors::Decryption
          raise Domain::Services::PayrollCsv::IntegrityError
        end
      end
    end
  end
end
