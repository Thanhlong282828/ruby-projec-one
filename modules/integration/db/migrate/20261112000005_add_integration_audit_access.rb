class AddIntegrationAuditAccess < ActiveRecord::Migration[8.1]
  def up
    add_index :audit_logs, [ :company_id, :record_type, :created_at, :id ], name: "integration_audit_lookup"
    now = connection.quote(Time.current)
    key = connection.quote("integration.audit.read")
    name = connection.quote("Xem nhật ký tích hợp trong company")
    execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{key},#{name},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{key})"
    execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{key} WHERE r.`key`='admin' AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve provisioned audit grants"
  end
end
