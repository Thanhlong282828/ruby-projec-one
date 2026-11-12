# typed: strict

module HrmPayroll
  module Domain
    Snapshot = T.type_alias do
      { "basis" => String, "captured_at" => String,
        "payslip_count" => Integer, "attendance_count" => Integer,
        "open_attendance_count" => Integer, "pending_leave_count" => Integer,
        "approved_leave_days" => Integer, "invalid_payslip_count" => Integer,
        "gross_total" => Integer, "deductions_total" => Integer, "net_total" => Integer }
    end
  end
end
