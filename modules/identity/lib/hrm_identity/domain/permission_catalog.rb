module HrmIdentity
  module Domain
    # Bootstrap defaults only. Authorization reads MySQL, never this constant.
    class PermissionCatalog
      DEFINITIONS = {
        "system.companies.read" => "Xem danh mục công ty toàn hệ thống",
        "system.companies.manage" => "Quản lý công ty và memberships toàn hệ thống",
        "dashboard.view" => "Xem tổng quan",
        "employees.read" => "Xem hồ sơ bản thân",
        "employees.read_all" => "Xem nhân sự trong company",
        "employees.create" => "Thêm nhân sự",
        "employees.update" => "Sửa nhân sự",
        "employees.delete" => "Xóa nhân sự",
        "employees.sensitive" => "Xem lương và thông tin riêng tư",
        "departments.read" => "Xem phòng ban",
        "departments.create" => "Thêm phòng ban",
        "departments.update" => "Sửa phòng ban",
        "departments.delete" => "Xóa phòng ban",
        "attendance.read" => "Xem chấm công bản thân",
        "attendance.read_all" => "Xem chấm công company",
        "attendance.clock" => "Vào ca và ra ca bản thân",
        "leave.read" => "Xem đơn phép bản thân",
        "leave.read_all" => "Xem đơn phép company",
        "leave.submit" => "Gửi đơn phép bản thân",
        "leave.submit_for_others" => "Gửi đơn phép cho nhân viên",
        "leave.review" => "Duyệt hoặc từ chối đơn phép",
        "payroll.read" => "Xem bảng lương company",
        "payroll.create" => "Tạo kỳ lương",
        "payroll.finalize" => "Chốt kỳ lương",
        "recruitment.read" => "Xem ứng viên",
        "recruitment.write" => "Thêm và sửa ứng viên",
        "audit.read" => "Xem nhật ký company",
        "realtime.read" => "Nhận cập nhật realtime company",
        "company.manage" => "Quản lý company",
        "accounts.manage" => "Quản lý tài khoản company",
        "roles.manage" => "Quản lý quyền trong company"
      }.freeze
      DEFAULTS = {
        "admin" => [ "dashboard.view", "employees.read", "employees.read_all", "employees.create", "employees.update", "employees.delete", "employees.sensitive", "departments.read", "departments.create", "departments.update", "departments.delete", "attendance.read", "attendance.read_all", "attendance.clock", "leave.read", "leave.read_all", "leave.submit", "leave.submit_for_others", "leave.review", "payroll.read", "payroll.create", "payroll.finalize", "recruitment.read", "recruitment.write", "audit.read", "realtime.read", "company.manage", "accounts.manage", "roles.manage" ],
        "hr" => [ "dashboard.view", "employees.read", "employees.read_all", "employees.create", "employees.update", "employees.sensitive", "departments.read", "departments.create", "departments.update", "attendance.read", "attendance.read_all", "attendance.clock", "leave.read", "leave.read_all", "leave.submit", "leave.submit_for_others", "leave.review", "payroll.read", "payroll.create", "payroll.finalize", "recruitment.read", "recruitment.write", "realtime.read" ],
        "manager" => [ "dashboard.view", "employees.read", "attendance.read", "attendance.clock", "leave.read", "leave.submit", "leave.read_all", "leave.review", "departments.read" ],
        "employee" => [ "dashboard.view", "employees.read", "attendance.read", "attendance.clock", "leave.read", "leave.submit" ]
      }.freeze
      ROLE_NAMES = { "admin" => "Quản trị company", "hr" => "Nhân sự", "manager" => "Quản lý", "employee" => "Nhân viên" }.freeze
      PROTECTED = %w[dashboard.view company.manage accounts.manage roles.manage].freeze
      # Engines register catalog names; identity never depends on a specific business module.
      def self.extensions = Array(Rails.application.config.x.hrm.permission_catalogs).map(&:constantize)
      def self.definitions = extensions.reduce(DEFINITIONS) { |result, catalog| result.merge(catalog::DEFINITIONS) }
      def self.defaults
        DEFAULTS.to_h { |role, grants| [ role, (grants + extensions.flat_map { |catalog| catalog.for_role(role) }).uniq ] }
      end
      def self.install!(company)
        definitions.each { |key, name| Permission.find_or_create_by!(key: key) { |p| p.name = name } }
        defaults.each do |key, grants|
          role = company.company_roles.create!(key: key, name: ROLE_NAMES.fetch(key))
          role.permissions = Permission.where(key: grants)
        end
      end
    end
  end
end
