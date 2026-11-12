# typed: strict

module HrmPayroll
  module Infrastructure
    module Persistence
      # Metadata only; the repository authorizes public reads.
      class PayrollReconciliation
        extend T::Sig

        sig { params(run: PayRun, lock: T::Boolean).returns(Domain::Snapshot) }
        def self.capture(run:, lock: false)
          scope = run.payslips.where(company_id: run.company_id).order(:id)
          slips = (lock ? scope.lock : scope).to_a
          employee_ids = slips.pluck(:employee_id)
          first, last = run.period.beginning_of_month, run.period.end_of_month
          attendance_scope = ::Attendance.where(company_id: run.company_id, employee_id: employee_ids, work_date: first..last).order(:id)
          leave_scope = ::LeaveRequest.where(company_id: run.company_id, employee_id: employee_ids, status: %w[pending approved])
            .where("starts_on <= ? AND ends_on >= ?", last, first).order(:id)
          attendances = (lock ? attendance_scope.lock : attendance_scope).to_a
          leaves = (lock ? leave_scope.lock : leave_scope).to_a
          { "basis" => "base_salary_snapshot_v1", "captured_at" => Time.current.iso8601,
            "payslip_count" => slips.length, "attendance_count" => attendances.length,
            "open_attendance_count" => attendances.count { |record| record.checked_out_at.nil? },
            "pending_leave_count" => leaves.count(&:pending?),
            "approved_leave_days" => leaves.select(&:approved?).sum { |record| ([ record.ends_on, last ].min - [ record.starts_on, first ].max).to_i + 1 },
            "invalid_payslip_count" => slips.count { |record| record.employee_code_snapshot.blank? || record.employee_name_snapshot.blank? || record.gross_cents.negative? || record.deductions_cents.negative? || record.net_cents.negative? || record.net_cents != record.gross_cents - record.deductions_cents },
            "gross_total" => slips.sum(&:gross_cents), "deductions_total" => slips.sum(&:deductions_cents), "net_total" => slips.sum(&:net_cents) }
        end
      end
    end
  end
end
