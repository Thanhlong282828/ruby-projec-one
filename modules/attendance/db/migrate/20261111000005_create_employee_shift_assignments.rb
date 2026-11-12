class CreateEmployeeShiftAssignments < ActiveRecord::Migration[8.1]
  ACTIONS = { "read"=>"Xem phân ca của mình", "read_all"=>"Xem phân ca company", "create"=>"Tạo phân ca", "update"=>"Kết thúc phân ca", "delete"=>"Xóa phân ca tương lai" }.freeze
  def up
    create_table :employee_shift_assignments do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :employee_id, null: false
      t.bigint :work_shift_id, null: false
      t.date :effective_from, null: false
      t.date :effective_to
      t.json :shift_snapshot, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :employee_shift_assignments, [ :company_id, :employee_id, :effective_from ], unique: true, name: "shift_assignment_lookup"
    add_foreign_key :employee_shift_assignments, :employees, column: [ :company_id, :employee_id ], primary_key: [ :company_id, :id ], name: "shift_assignment_employee"
    add_foreign_key :employee_shift_assignments, :work_shifts, column: [ :company_id, :work_shift_id ], primary_key: [ :company_id, :id ], name: "shift_assignment_shift"
    add_check_constraint :employee_shift_assignments, "effective_to IS NULL OR effective_to >= effective_from", name: "shift_assignment_dates"
    now = connection.quote(Time.current)
    ACTIONS.each do |action, label|
      key=connection.quote("shift_assignments.#{action}")
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{key},#{connection.quote(label)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{key})"
      roles = case action
      when "read" then %w[admin hr manager employee]
      when "read_all" then %w[admin hr manager]
      when "delete" then %w[admin]
      else %w[admin hr]
      end
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{key} WHERE r.`key` IN (#{roles.map { |role| connection.quote(role) }.join(',')}) AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve assignment history and grants"
  end
end
