class AddCompanyRbac < ActiveRecord::Migration[8.1]
  PERMISSIONS = {
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
        "roles.manage" => "Quản lý quyền trong company",
      }.freeze
  DEFAULTS = {
        "admin" => ["dashboard.view", "employees.read", "employees.read_all", "employees.create", "employees.update", "employees.delete", "employees.sensitive", "departments.read", "departments.create", "departments.update", "departments.delete", "attendance.read", "attendance.read_all", "attendance.clock", "leave.read", "leave.read_all", "leave.submit", "leave.submit_for_others", "leave.review", "payroll.read", "payroll.create", "payroll.finalize", "recruitment.read", "recruitment.write", "audit.read", "realtime.read", "company.manage", "accounts.manage", "roles.manage"],
        "hr" => ["dashboard.view", "employees.read", "employees.read_all", "employees.create", "employees.update", "employees.sensitive", "departments.read", "departments.create", "departments.update", "attendance.read", "attendance.read_all", "attendance.clock", "leave.read", "leave.read_all", "leave.submit", "leave.submit_for_others", "leave.review", "payroll.read", "payroll.create", "payroll.finalize", "recruitment.read", "recruitment.write", "realtime.read"],
        "manager" => ["dashboard.view", "employees.read", "attendance.read", "attendance.clock", "leave.read", "leave.submit", "leave.read_all", "leave.review", "departments.read"],
        "employee" => ["dashboard.view", "employees.read", "attendance.read", "attendance.clock", "leave.read", "leave.submit"],
      }.freeze
  TENANT_TABLES = %i[users departments employees attendances leave_requests pay_runs payslips candidates audit_logs outbox_events].freeze
  def up
    create_table :companies do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :companies, :code, unique: true
    execute "INSERT INTO companies (code,name,active,created_at,updated_at) VALUES ('XINVIEC','Xin Viec',1,NOW(),NOW())"
    company_id = select_value("SELECT id FROM companies WHERE code='XINVIEC'").to_i
    TENANT_TABLES.each do |table|
      add_reference table, :company, null: true, foreign_key: true
      execute "UPDATE #{table} SET company_id=#{company_id} WHERE company_id IS NULL"
      change_column_null table, :company_id, false
    end
    create_table :permissions do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :permissions, :key, unique: true
    create_table :company_roles do |t|
      t.references :company, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :company_roles, [:company_id, :key], unique: true
    create_table :role_permissions do |t|
      t.references :company_role, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
    end
    add_index :role_permissions, [:company_role_id, :permission_id], unique: true, name: 'idx_role_permission_unique'
    create_table :user_permissions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.boolean :granted, null: false
      t.timestamps
    end
    add_index :user_permissions, [:user_id, :permission_id], unique: true
    PERMISSIONS.each do |key, name|
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) VALUES (#{quote(key)},#{quote(name)},NOW(),NOW())"
    end
    DEFAULTS.each do |key, grants|
      execute "INSERT INTO company_roles (company_id,`key`,name,created_at,updated_at) VALUES (#{company_id},#{quote(key)},#{quote(key)},NOW(),NOW())"
      role_id = select_value("SELECT id FROM company_roles WHERE company_id=#{company_id} AND `key`=#{quote(key)}").to_i
      grants.each do |permission|
        execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT #{role_id},id FROM permissions WHERE `key`=#{quote(permission)}"
      end
    end
    # Tenant-local identifiers can repeat between companies; login email stays globally unique.
    remove_index :departments, :code
    add_index :departments, [:company_id, :code], unique: true
    remove_index :employees, :employee_code
    add_index :employees, [:company_id, :employee_code], unique: true
    remove_index :employees, :email
    add_index :employees, [:company_id, :email], unique: true
    remove_index :pay_runs, :period
    add_index :pay_runs, [:company_id, :period], unique: true
    %i[users departments employees pay_runs].each { |table| add_index table, [:company_id, :id], unique: true }
    {employees: {department_id: :departments, user_id: :users}, attendances: {employee_id: :employees}, leave_requests: {employee_id: :employees, reviewer_id: :users}, pay_runs: {created_by_id: :users}, payslips: {employee_id: :employees, pay_run_id: :pay_runs}, audit_logs: {actor_id: :users}}.each do |child, links|
      links.each do |column, parent|
        add_foreign_key child, parent, column: [:company_id, column], primary_key: [:company_id, :id], name: "fk_tenant_#{child}_#{column}"
      end
    end
  end
  def down
    raise ActiveRecord::IrreversibleMigration, 'Company isolation and grants contain business data; restore a reviewed backup instead of dropping tenants.'
  end
end
