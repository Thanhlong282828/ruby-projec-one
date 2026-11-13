class CreateGoodsReceipts < ActiveRecord::Migration[8.1]
  def up
    create_table :goods_receipts do |t|
      t.bigint :company_id, null: false
      t.bigint :purchase_order_id, null: false
      t.bigint :received_by_id, null: false
      t.string :code, limit: 32, null: false
      t.string :status, limit: 20, null: false, default: "recording"
      t.date :received_on, null: false
      t.text :delivery_reference
      t.string :idempotency_key, limit: 64, null: false, collation: "utf8mb4_bin"
      t.string :content_digest, limit: 64, null: false
      t.timestamps
    end
    add_index :goods_receipts, [ :company_id, :idempotency_key ], unique: true, name: "receipt_idempotency"
    add_index :goods_receipts, [ :company_id, :code ], unique: true, name: "receipt_company_code"
    add_index :goods_receipts, [ :company_id, :purchase_order_id, :id ], unique: true, name: "receipt_order_identity"
    add_index :goods_receipts, [ :company_id, :status, :id ], name: "receipt_company_queue"
    add_foreign_key :goods_receipts, :purchase_orders, column: [ :company_id, :purchase_order_id ], primary_key: [ :company_id, :id ], on_delete: :cascade, name: "receipt_order_company"
    add_foreign_key :goods_receipts, :users, column: [ :company_id, :received_by_id ], primary_key: [ :company_id, :id ], name: "receipt_actor_company"
    add_check_constraint :goods_receipts, "status IN ('recording','recorded')", name: "receipt_state"
    add_index :purchase_order_lines, [ :company_id, :purchase_order_id, :id ], unique: true, name: "order_line_receiving_identity"
    create_table :goods_receipt_lines do |t|
      t.bigint :company_id, null: false
      t.bigint :purchase_order_id, null: false
      t.bigint :goods_receipt_id, null: false
      t.bigint :purchase_order_line_id, null: false
      t.decimal :quantity, precision: 9, scale: 3, null: false
      t.timestamps
    end
    add_index :goods_receipt_lines, [ :goods_receipt_id, :purchase_order_line_id ], unique: true, name: "receipt_unique_order_line"
    add_foreign_key :goods_receipt_lines, :goods_receipts, column: [ :company_id, :purchase_order_id, :goods_receipt_id ], primary_key: [ :company_id, :purchase_order_id, :id ], on_delete: :cascade, name: "receipt_line_parent_company"
    add_foreign_key :goods_receipt_lines, :purchase_order_lines, column: [ :company_id, :purchase_order_id, :purchase_order_line_id ], primary_key: [ :company_id, :purchase_order_id, :id ], on_delete: :cascade, name: "receipt_line_order_company"
    add_check_constraint :goods_receipt_lines, "quantity>0", name: "receipt_line_positive"
    # MySQL can discard this legacy FK-support index while importing the old SQL
    # snapshot because the newer composite unique index covers the same prefix.
    # Preserve the canonical index set on both migrated and freshly loaded schemas.
    unless index_exists?(:purchase_request_lines, [ :company_id, :purchase_request_id ], name: "purchase_line_company_source")
      add_index :purchase_request_lines, [ :company_id, :purchase_request_id ], name: "purchase_line_company_source"
    end
    guards
    now = connection.quote(Time.current)
    { "procurement.receipts.read" => "Xem phiếu nhận hàng", "procurement.receipts.create" => "Ghi nhận hàng" }.each do |key, name|
      quoted = connection.quote(key)
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{quoted},#{connection.quote(name)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{quoted})"
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{quoted} WHERE r.`key` IN ('admin','manager') AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve receiving history"
  end
  private
  def guards
    execute <<~SQL.squish
      CREATE TRIGGER goods_receipt_insert_guard BEFORE INSERT ON goods_receipts FOR EACH ROW
      BEGIN
        DECLARE parent_state VARCHAR(20);
        SELECT status INTO parent_state FROM purchase_orders WHERE company_id=NEW.company_id AND id=NEW.purchase_order_id FOR UPDATE;
        IF parent_state IS NULL OR parent_state<>'issued' OR NEW.status<>'recording' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Receiving requires issued PO'; END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER goods_receipt_update_guard BEFORE UPDATE ON goods_receipts FOR EACH ROW
      BEGIN
        DECLARE item_count INT;
        DECLARE over_count INT;
        SELECT COUNT(*) INTO item_count FROM goods_receipt_lines WHERE company_id=OLD.company_id AND goods_receipt_id=OLD.id FOR UPDATE;
        SELECT COUNT(*) INTO over_count FROM purchase_order_lines pol WHERE pol.company_id=OLD.company_id AND pol.purchase_order_id=OLD.purchase_order_id AND pol.quantity < (SELECT COALESCE(SUM(grl.quantity),0) FROM goods_receipt_lines grl WHERE grl.company_id=pol.company_id AND grl.purchase_order_line_id=pol.id FOR UPDATE) FOR UPDATE;
        IF over_count>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Received quantity exceeds ordered'; END IF;
        IF OLD.status<>'recording' OR NEW.status<>'recorded' OR item_count<1 OR NEW.company_id<>OLD.company_id OR NEW.purchase_order_id<>OLD.purchase_order_id OR NEW.received_by_id<>OLD.received_by_id OR NEW.code<>OLD.code OR NEW.received_on<>OLD.received_on OR NOT(NEW.delivery_reference<=>OLD.delivery_reference) OR NEW.idempotency_key<>OLD.idempotency_key OR NEW.content_digest<>OLD.content_digest OR NEW.created_at<>OLD.created_at THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recorded receipt is immutable'; END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER goods_receipt_delete_guard BEFORE DELETE ON goods_receipts FOR EACH ROW
      BEGIN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Receipt history cannot be deleted';
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER goods_receipt_line_insert_guard BEFORE INSERT ON goods_receipt_lines FOR EACH ROW
      BEGIN
        DECLARE parent_state VARCHAR(20);
        DECLARE receipt_state VARCHAR(20);
        DECLARE ordered_qty DECIMAL(9,3);
        SELECT status INTO parent_state FROM purchase_orders WHERE company_id=NEW.company_id AND id=NEW.purchase_order_id FOR UPDATE;
        SELECT status INTO receipt_state FROM goods_receipts WHERE company_id=NEW.company_id AND purchase_order_id=NEW.purchase_order_id AND id=NEW.goods_receipt_id FOR UPDATE;
        SELECT quantity INTO ordered_qty FROM purchase_order_lines WHERE company_id=NEW.company_id AND purchase_order_id=NEW.purchase_order_id AND id=NEW.purchase_order_line_id FOR UPDATE;
        IF parent_state IS NULL OR parent_state<>'issued' OR receipt_state IS NULL OR receipt_state<>'recording' OR ordered_qty IS NULL OR NEW.quantity>ordered_qty THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid or excessive received quantity'; END IF;
      END
    SQL
    %w[UPDATE DELETE].each do |operation|
      execute "CREATE TRIGGER goods_receipt_line_#{operation.downcase}_guard BEFORE #{operation} ON goods_receipt_lines FOR EACH ROW BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Receipt lines are immutable'; END"
    end
  end
end
