class BindPayrollExportDeliveries < ActiveRecord::Migration[8.1]
  def up
    add_column :integration_deliveries, :payroll_export_id, :bigint
    add_index :integration_deliveries, [ :company_id, :payroll_export_id ], name: "delivery_payroll_source"
    add_foreign_key :integration_deliveries, :payroll_exports, column: [ :company_id, :payroll_export_id ], primary_key: [ :company_id, :id ], name: "delivery_company_payroll_source"
    now = connection.quote(Time.current)
    key = connection.quote("payroll.exports.notify")
    execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{key},'Gửi thông báo snapshot bảng lương',#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{key})"
    execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{key} WHERE r.`key`='admin' AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve source-bound delivery history"
  end
end
