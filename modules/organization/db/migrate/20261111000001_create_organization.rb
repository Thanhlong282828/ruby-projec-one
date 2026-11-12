class CreateOrganization < ActiveRecord::Migration[8.1]
  RESOURCES = { "cost_centers" => "trung tâm chi phí", "organization_units" => "đơn vị tổ chức", "job_positions" => "vị trí", "employee_assignments" => "phân công" }.freeze
  ACTIONS = { "read" => "Xem", "create" => "Tạo", "update" => "Sửa", "delete" => "Xóa", "export" => "Xuất" }.freeze
  def up
    create_table :cost_centers do |t|
      t.references :company, null: false, foreign_key: true
      t.string :code, null: false, limit: 30
      t.string :name, null: false
      t.decimal :annual_budget, precision: 18, scale: 2, null: false, default: 0
      t.string :currency, limit: 3, null: false, default: "VND"
      t.timestamps
    end
    create_table :organization_units do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :parent_id
      t.bigint :cost_center_id
      t.string :code, null: false, limit: 30
      t.string :name, null: false
      t.string :unit_type, null: false
      t.integer :headcount_limit, null: false, default: 0
      t.date :effective_from, null: false
      t.date :effective_to
      t.timestamps
    end
    create_table :job_positions do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :organization_unit_id, null: false
      t.string :code, null: false, limit: 30
      t.string :title, null: false
      t.string :job_grade, limit: 50
      t.integer :career_level, null: false, default: 1
      t.integer :approved_headcount, null: false, default: 0
      t.decimal :budgeted_cost, precision: 18, scale: 2, null: false, default: 0
      t.boolean :is_critical, null: false, default: false
      t.timestamps
    end
    create_table :employee_assignments do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :employee_id, null: false
      t.bigint :organization_unit_id, null: false
      t.bigint :job_position_id, null: false
      t.date :effective_from, null: false
      t.date :effective_to
      t.decimal :allocation_percent, precision: 5, scale: 2, null: false, default: 100
      t.timestamps
    end
    [ :cost_centers, :organization_units, :job_positions, :employee_assignments ].each do |table|
      add_index table, [ :company_id, :id ], unique: true
    end
    [ :cost_centers, :organization_units, :job_positions ].each { |table| add_index table, [ :company_id, :code ], unique: true }
    tenant_fk(:organization_units, :organization_units, :parent_id, "org_unit_parent")
    tenant_fk(:organization_units, :cost_centers, :cost_center_id, "org_unit_cost")
    tenant_fk(:job_positions, :organization_units, :organization_unit_id, "org_position_unit")
    tenant_fk(:employee_assignments, :employees, :employee_id, "org_assignment_employee")
    tenant_fk(:employee_assignments, :organization_units, :organization_unit_id, "org_assignment_unit")
    tenant_fk(:employee_assignments, :job_positions, :job_position_id, "org_assignment_position")
    add_check_constraint :cost_centers, "annual_budget >= 0", name: "org_budget_nonnegative"
    add_check_constraint :organization_units, "headcount_limit >= 0 AND (effective_to IS NULL OR effective_to >= effective_from)", name: "org_unit_limits"
    add_check_constraint :job_positions, "career_level BETWEEN 1 AND 6 AND approved_headcount >= 0 AND budgeted_cost >= 0", name: "org_position_limits"
    add_check_constraint :employee_assignments, "allocation_percent > 0 AND allocation_percent <= 100 AND (effective_to IS NULL OR effective_to >= effective_from)", name: "org_assignment_limits"
    now = connection.quote(Time.current)
    RESOURCES.each do |resource, name|
      ACTIONS.each do |action, label|
        key = connection.quote("#{resource}.#{action}")
        execute "INSERT INTO permissions (`key`, name, created_at, updated_at) SELECT #{key}, #{connection.quote("#{label} #{name}")}, #{now}, #{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key` = #{key})"
        roles = action == "read" ? %w[admin hr manager] : (action == "delete" ? %w[admin] : %w[admin hr])
        execute "INSERT INTO role_permissions (company_role_id, permission_id) SELECT r.id, p.id FROM company_roles r JOIN permissions p ON p.`key` = #{key} WHERE r.`key` IN (#{roles.map { |r| connection.quote(r) }.join(',')}) AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
      end
    end
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Organization may contain staffing history; restore a verified backup instead"
  end
  private
  def tenant_fk(from, to, column, name)
    add_foreign_key from, to, column: [ :company_id, column ], primary_key: [ :company_id, :id ], name: name
  end
end
