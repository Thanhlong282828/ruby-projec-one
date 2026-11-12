class CreateIntegrationDeliveries < ActiveRecord::Migration[8.1]
  def up
    create_table :integration_deliveries do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :integration_connection_id, null: false
      t.bigint :requested_by_id, null: false
      t.string :target_key, null: false, limit: 40
      t.string :event_id, null: false, limit: 36, collation: "utf8mb4_bin"
      t.string :idempotency_key, null: false, limit: 100, collation: "utf8mb4_bin"
      t.text :payload, null: false, size: :medium
      t.string :body_digest, null: false, limit: 64
      t.string :status, null: false, default: "queued", limit: 20
      t.integer :attempt_count, null: false, default: 0
      t.integer :replay_count, null: false, default: 0
      t.datetime :available_at, null: false
      t.datetime :delivered_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :integration_deliveries, [ :company_id, :id ], unique: true
    add_index :integration_deliveries, [ :company_id, :idempotency_key ], unique: true, name: "delivery_idempotency"
    add_index :integration_deliveries, :event_id, unique: true
    add_index :integration_deliveries, [ :status, :available_at ], name: "delivery_due"
    add_foreign_key :integration_deliveries, :integration_connections, column: [ :company_id, :integration_connection_id ], primary_key: [ :company_id, :id ], name: "delivery_company_connection"
    add_foreign_key :integration_deliveries, :users, column: [ :company_id, :requested_by_id ], primary_key: [ :company_id, :id ], name: "delivery_company_requester"
    add_check_constraint :integration_deliveries, "status IN ('queued','retry_wait','delivered','dead_letter','blocked')", name: "delivery_status"
    add_check_constraint :integration_deliveries, "attempt_count >= 0 AND attempt_count <= 55 AND replay_count >= 0 AND replay_count <= 10", name: "delivery_attempt_bounds"
    create_table :integration_delivery_attempts do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :integration_delivery_id, null: false
      t.integer :sequence, null: false
      t.integer :http_status
      t.string :outcome, null: false, limit: 30
      t.datetime :started_at, null: false
      t.datetime :completed_at, null: false
      t.timestamps
    end
    add_index :integration_delivery_attempts, [ :integration_delivery_id, :sequence ], unique: true, name: "delivery_attempt_sequence"
    add_foreign_key :integration_delivery_attempts, :integration_deliveries, column: [ :company_id, :integration_delivery_id ], primary_key: [ :company_id, :id ], name: "attempt_company_delivery"
    now = connection.quote(Time.current)
    { "send" => "Xếp hàng gửi webhook company", "retry" => "Retry và replay webhook company" }.each do |suffix, name|
      key = connection.quote("integration.#{suffix}")
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{key},#{connection.quote(name)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{key})"
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{key} WHERE r.`key`='admin' AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve delivery and attempt history"
  end
end
