class CreateOnboardingCases < ActiveRecord::Migration[8.1]
  def up
    create_table :onboarding_cases do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :employee_id, null: false
      t.date :start_date, null: false
      t.string :status, null: false, default: "preboarding", limit: 30
      t.json :checklist, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :onboarding_cases, [ :company_id, :employee_id, :start_date ], unique: true, name: "onboarding_employee_start"
    add_foreign_key :onboarding_cases, :employees, column: [ :company_id, :employee_id ], primary_key: [ :company_id, :id ], name: "onboarding_company_employee"
    add_check_constraint :onboarding_cases, "status IN ('draft','ready','preboarding','in_progress','blocked','probation_review','completed','cancelled')", name: "onboarding_status"
    now = connection.quote(Time.current)
    { "onboarding.read" => "Xem tiếp nhận bản thân", "onboarding.read_all" => "Xem tiếp nhận company", "onboarding.create" => "Tạo hồ sơ tiếp nhận", "onboarding.manage" => "Xử lý tiếp nhận và checklist" }.each do |key, name|
      quoted = connection.quote(key)
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{quoted},#{connection.quote(name)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{quoted})"
      roles = key == "onboarding.read" ? %w[admin hr manager employee] : %w[admin hr]
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{quoted} WHERE r.`key` IN (#{roles.map { |role| connection.quote(role) }.join(',')}) AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve onboarding history and grants"
  end
end
