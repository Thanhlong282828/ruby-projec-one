class CreateIntegrationHub < ActiveRecord::Migration[8.1]
  def up
    create_table :integration_connections do |t|
      t.references :company, null: false, foreign_key: true
      t.string :public_id, null: false, limit: 36, collation: "utf8mb4_bin"
      t.string :code, null: false, limit: 30
      t.string :name, null: false, limit: 150
      t.text :signing_secret, null: false
      t.boolean :active, null: false, default: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :integration_connections, :public_id, unique: true
    add_index :integration_connections, [ :company_id, :code ], unique: true
    add_index :integration_connections, [ :company_id, :id ], unique: true
    create_table :integration_webhooks do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :integration_connection_id, null: false
      t.string :event_id, null: false, limit: 100, collation: "utf8mb4_bin"
      t.string :event_type, null: false, limit: 100
      t.string :body_digest, null: false, limit: 64
      t.text :payload, null: false, size: :medium
      t.string :status, null: false, default: "received", limit: 20
      t.text :review_note
      t.datetime :reviewed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :integration_webhooks, [ :integration_connection_id, :event_id ], unique: true, name: "webhook_event_identity"
    add_index :integration_webhooks, [ :company_id, :status, :id ], name: "webhook_inbox_filter"
    add_foreign_key :integration_webhooks, :integration_connections, column: [ :company_id, :integration_connection_id ], primary_key: [ :company_id, :id ], name: "webhook_company_connection"
    add_check_constraint :integration_webhooks, "status IN ('received','acknowledged','rejected')", name: "webhook_review_status"
    add_check_constraint :integration_webhooks, "(status = 'received' AND reviewed_at IS NULL) OR (status <> 'received' AND reviewed_at IS NOT NULL)", name: "webhook_review_timestamp"
    now = connection.quote(Time.current)
    { "read" => "Xem kết nối và metadata webhook company", "create" => "Tạo kết nối webhook", "manage" => "Bật/tắt kết nối và đổi khóa webhook", "review" => "Xác nhận hoặc từ chối sự kiện nhận", "payload.read" => "Xem nội dung webhook nhạy cảm" }.each do |suffix, name|
      key = connection.quote("integration.#{suffix}")
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{key},#{connection.quote(name)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{key})"
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{key} WHERE r.`key`='admin' AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve integration credentials, receipts and history"
  end
end
