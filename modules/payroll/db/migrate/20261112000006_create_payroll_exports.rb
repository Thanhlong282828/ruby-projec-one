class CreatePayrollExports < ActiveRecord::Migration[8.1]
  def up
    create_table :payroll_exports do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :pay_run_id, null: false
      t.bigint :created_by_id, null: false
      t.string :public_id, null: false, limit: 36, collation: "utf8mb4_bin"
      t.date :period, null: false
      t.string :format, null: false, default: "payroll_csv_v1", limit: 40
      t.integer :version, null: false, default: 1
      t.integer :employee_count, null: false
      t.integer :byte_size, null: false
      t.string :checksum, null: false, limit: 64
      t.text :artifact, null: false, size: :medium
      t.timestamps
    end
    add_index :payroll_exports, [ :company_id, :id ], unique: true
    add_index :payroll_exports, [ :company_id, :pay_run_id ], unique: true
    add_index :payroll_exports, :public_id, unique: true
    add_index :payroll_exports, [ :company_id, :period, :id ]
    add_foreign_key :payroll_exports, :pay_runs, column: [ :company_id, :pay_run_id ], primary_key: [ :company_id, :id ], name: "export_company_pay_run"
    add_foreign_key :payroll_exports, :users, column: [ :company_id, :created_by_id ], primary_key: [ :company_id, :id ], name: "export_company_creator"
    add_check_constraint :payroll_exports, "version = 1 AND format = 'payroll_csv_v1' AND employee_count BETWEEN 1 AND 2000 AND byte_size BETWEEN 1 AND 1048576", name: "payroll_export_bounds"
    create_table :payroll_export_accesses do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :payroll_export_id, null: false
      t.bigint :actor_id, null: false
      t.string :result, null: false, limit: 30
      t.timestamps
    end
    add_index :payroll_export_accesses, [ :company_id, :payroll_export_id, :id ], name: "export_access_history"
    add_foreign_key :payroll_export_accesses, :payroll_exports, column: [ :company_id, :payroll_export_id ], primary_key: [ :company_id, :id ], name: "access_company_export"
    add_foreign_key :payroll_export_accesses, :users, column: [ :company_id, :actor_id ], primary_key: [ :company_id, :id ], name: "access_company_actor"
    add_check_constraint :payroll_export_accesses, "result IN ('allowed','integrity_failed')", name: "export_access_result"
    now = connection.quote(Time.current)
    { "read" => "Xem tệp xuất bảng lương company", "create" => "Tạo snapshot CSV bảng lương đã chốt", "download" => "Tải tệp xuất bảng lương nhạy cảm" }.each do |suffix, name|
      key = connection.quote("payroll.exports.#{suffix}")
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{key},#{connection.quote(name)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{key})"
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{key} WHERE r.`key`='admin' AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve payroll artifacts and access history"
  end
end
