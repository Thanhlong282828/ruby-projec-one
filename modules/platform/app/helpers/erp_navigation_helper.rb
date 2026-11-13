module ErpNavigationHelper
  HEADCOUNT_PERMISSIONS = %w[organization_units.read job_positions.read employee_assignments.read].freeze
  # Presentation catalog only: authorization remains enforced by every use case.
  ERP_AREAS = [
    [ "Nhân sự", [
      [ "Hồ sơ nhân viên", "/employees", %w[employees.read employees.read_all] ]
    ] ],
    [ "Cơ cấu tổ chức", [
      [ "Phòng ban", "/departments", %w[departments.read] ],
      [ "Chi nhánh", "/organization/branches", %w[organization_units.read] ],
      [ "Cây tổ chức", "/organization/tree", %w[organization_units.read] ],
      [ "Đơn vị tổ chức", "/organization/organization-units", %w[organization_units.read] ],
      [ "Trung tâm chi phí", "/organization/cost-centers", %w[cost_centers.read] ],
      [ "Vị trí công việc", "/organization/job-positions", %w[job_positions.read] ],
      [ "Phân công nhân sự", "/organization/employee-assignments", %w[employee_assignments.read] ]
    ] ],
    [ "Chấm công", [
      [ "Chấm công", "/attendances", %w[attendance.read attendance.read_all] ],
      [ "Báo cáo công theo kỳ", "/attendances/report", %w[attendance.read attendance.read_all] ],
      [ "Ca làm việc", "/work_shifts", %w[work_shifts.read] ],
      [ "Phân ca & lịch công", "/shift_assignments", %w[shift_assignments.read shift_assignments.read_all] ]
    ] ],
    [ "Nghỉ phép", [
      [ "Nghỉ phép", "/leave_requests", %w[leave.read leave.read_all] ]
    ] ],
    [ "Bảng lương", [
      [ "Bảng lương", "/pay_runs", %w[payroll.read] ],
      [ "Tệp xuất bảng lương", "/payroll/exports", %w[payroll.read payroll.exports.read], :all ]
    ] ],
    [ "Tuyển dụng", [ [ "Ứng viên", "/candidates", %w[recruitment.read] ] ] ],
    [ "Onboarding", [ [ "Tiếp nhận nhân viên", "/onboarding/cases", %w[onboarding.read onboarding.read_all] ] ] ],
    [ "Tích hợp", [
      [ "Nhận sự kiện & kết nối", "/integration", %w[integration.read] ],
      [ "Gửi sự kiện", "/integration/outbound", %w[integration.read] ],
      [ "Nhật ký tích hợp", "/integration/audit", %w[integration.read integration.audit.read], :all ]
    ] ],
    [ "Quản trị hệ thống", [
      [ "Công ty toàn hệ thống", "/system/companies", %w[system.companies.read] ],
      [ "Công ty", "/manage/company", %w[company.manage] ],
      [ "Tài khoản & quyền", "/manage/accounts", %w[accounts.manage] ],
      [ "Vai trò & quyền", "/manage/roles", %w[roles.manage] ],
      [ "Nhật ký kiểm toán", "/audit_logs", %w[audit.read] ]
    ] ]
  ].freeze

  def erp_navigation_groups
    # Memoized only within this request. No cross-user authorization cache.
    @erp_navigation_groups ||= ERP_AREAS.filter_map do |name, entries|
      visible = entries.select do |_, _, permissions, match|
        match == :all ? permissions.all? { |key| current_user.allowed?(key) } : permissions.any? { |key| current_user.allowed?(key) }
      end
      if name == "Cơ cấu tổ chức" && HEADCOUNT_PERMISSIONS.all? { |key| current_user.allowed?(key) }
        visible = visible + [ [ "Định biên nhân sự", "/organization/headcount", [] ] ]
      end
      { name: name, entries: visible } if visible.any?
    end
  end
end
