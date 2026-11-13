class CreateStockReturns < ActiveRecord::Migration[8.1]
  def up
    add_index :stock_receipts, [ :company_id, :warehouse_id, :id ], unique: true, name: "stock_receipt_return_identity"
    add_index :stock_movements, [ :company_id, :stock_receipt_id, :warehouse_id, :stock_item_id, :id ], unique: true, name: "stock_movement_return_identity"
    create_table :stock_returns do |t|
      t.bigint :company_id, null: false
      t.bigint :stock_receipt_id, null: false
      t.bigint :warehouse_id, null: false
      t.bigint :supplier_id, null: false
      t.bigint :posted_by_id, null: false
      t.string :code, limit: 32, null: false
      t.string :status, limit: 20, null: false, default: "posting"
      t.string :idempotency_key, limit: 64, collation: "utf8mb4_bin", null: false
      t.string :content_digest, limit: 64, null: false
      t.string :warehouse_code_snapshot, limit: 40, null: false
      t.string :warehouse_name_snapshot, limit: 200, null: false
      t.string :supplier_code_snapshot, limit: 40, null: false
      t.string :supplier_name_snapshot, limit: 200, null: false
      t.text :reason, null: false
      t.datetime :posted_at
      t.timestamps
    end
    add_index :stock_returns, [ :company_id, :idempotency_key ], unique: true, name: "stock_return_idempotency"
    add_index :stock_returns, [ :company_id, :code ], unique: true, name: "stock_return_code"
    add_index :stock_returns, [ :company_id, :stock_receipt_id, :warehouse_id, :id ], unique: true, name: "stock_return_source_identity"
    add_foreign_key :stock_returns, :stock_receipts, column: [ :company_id, :warehouse_id, :stock_receipt_id ], primary_key: [ :company_id, :warehouse_id, :id ], name: "stock_return_receipt_company"
    add_foreign_key :stock_returns, :procurement_suppliers, column: [ :company_id, :supplier_id ], primary_key: [ :company_id, :id ], name: "stock_return_supplier_company"
    add_foreign_key :stock_returns, :users, column: [ :company_id, :posted_by_id ], primary_key: [ :company_id, :id ], name: "stock_return_actor_company"
    add_check_constraint :stock_returns, "(status='posting' AND posted_at IS NULL) OR (status='posted' AND posted_at IS NOT NULL)", name: "stock_return_state"
    create_table :stock_return_lines do |t|
      t.bigint :company_id, null: false
      t.bigint :stock_return_id, null: false
      t.bigint :stock_receipt_id, null: false
      t.bigint :stock_movement_id, null: false
      t.bigint :warehouse_id, null: false
      t.bigint :stock_item_id, null: false
      t.string :item_code_snapshot, limit: 40, null: false
      t.string :item_name_snapshot, limit: 200, null: false
      t.string :unit, limit: 30, null: false
      t.decimal :quantity, precision: 9, scale: 3, null: false
      t.timestamps
    end
    add_index :stock_return_lines, [ :stock_return_id, :stock_movement_id ], unique: true, name: "stock_return_line_unique_source"
    add_index :stock_return_lines, [ :company_id, :stock_movement_id, :id ], name: "stock_return_source_totals"
    add_index :stock_return_lines, [ :company_id, :warehouse_id, :stock_item_id, :id ], name: "stock_return_balance_ledger"
    add_foreign_key :stock_return_lines, :stock_returns, column: [ :company_id, :stock_receipt_id, :warehouse_id, :stock_return_id ], primary_key: [ :company_id, :stock_receipt_id, :warehouse_id, :id ], name: "stock_return_line_parent_company"
    add_foreign_key :stock_return_lines, :stock_movements, column: [ :company_id, :stock_receipt_id, :warehouse_id, :stock_item_id, :stock_movement_id ], primary_key: [ :company_id, :stock_receipt_id, :warehouse_id, :stock_item_id, :id ], name: "stock_return_line_source_company"
    add_check_constraint :stock_return_lines, "quantity>0", name: "stock_return_line_positive"
    guards
    permissions
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve supplier return ledger"
  end
  private
  def guards
    execute <<~SQL.squish
      CREATE TRIGGER stock_return_insert_guard BEFORE INSERT ON stock_returns FOR EACH ROW
      BEGIN
        DECLARE source_state VARCHAR(20);
        DECLARE source_supplier BIGINT;
        DECLARE source_warehouse BIGINT;
        DECLARE warehouse_code VARCHAR(40);
        DECLARE warehouse_name VARCHAR(200);
        DECLARE supplier_code VARCHAR(40);
        DECLARE supplier_name VARCHAR(200);
        SELECT s.status,s.warehouse_id,s.warehouse_code_snapshot,s.warehouse_name_snapshot,p.supplier_id,p.supplier_code_snapshot,p.supplier_name_snapshot
          INTO source_state,source_warehouse,warehouse_code,warehouse_name,source_supplier,supplier_code,supplier_name
          FROM stock_receipts s INNER JOIN goods_receipts g ON g.company_id=s.company_id AND g.id=s.goods_receipt_id
          INNER JOIN purchase_orders p ON p.company_id=g.company_id AND p.id=g.purchase_order_id
          WHERE s.company_id=NEW.company_id AND s.id=NEW.stock_receipt_id FOR UPDATE;
        IF source_state IS NULL OR source_state<>'posted' OR NEW.status<>'posting' OR NEW.posted_at IS NOT NULL OR NEW.warehouse_id<>source_warehouse OR NEW.supplier_id<>source_supplier OR BINARY NEW.warehouse_code_snapshot<>BINARY warehouse_code OR BINARY NEW.warehouse_name_snapshot<>BINARY warehouse_name OR BINARY NEW.supplier_code_snapshot<>BINARY supplier_code OR BINARY NEW.supplier_name_snapshot<>BINARY supplier_name THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Return requires immutable posted source and its warehouse/supplier'; END IF;
      END
    SQL
    # Sum under the HEADER seal, not a self-reading INSERT trigger on return lines.
    # All lines reserve source quantity, including an operator's unsealed posting: fail closed.
    execute <<~SQL.squish
      CREATE TRIGGER stock_return_update_guard BEFORE UPDATE ON stock_returns FOR EACH ROW
      BEGIN
        DECLARE finished INT DEFAULT 0;
        DECLARE movement_id BIGINT;
        DECLARE source_qty DECIMAL(9,3);
        DECLARE used_qty DECIMAL(18,3);
        DECLARE source_state VARCHAR(20);
        DECLARE line_count INT;
        DECLARE source_cursor CURSOR FOR SELECT stock_movement_id FROM stock_return_lines WHERE company_id=OLD.company_id AND stock_return_id=OLD.id ORDER BY stock_movement_id;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished=1;
        SELECT status INTO source_state FROM stock_receipts WHERE company_id=OLD.company_id AND id=OLD.stock_receipt_id FOR UPDATE;
        SELECT COUNT(*) INTO line_count FROM stock_return_lines WHERE company_id=OLD.company_id AND stock_return_id=OLD.id FOR UPDATE;
        IF OLD.status<>'posting' OR NEW.status<>'posted' OR NEW.posted_at IS NULL OR source_state<>'posted' OR line_count<1 OR NEW.company_id<>OLD.company_id OR NEW.stock_receipt_id<>OLD.stock_receipt_id OR NEW.warehouse_id<>OLD.warehouse_id OR NEW.supplier_id<>OLD.supplier_id OR NEW.posted_by_id<>OLD.posted_by_id OR BINARY NEW.code<>BINARY OLD.code OR BINARY NEW.idempotency_key<>BINARY OLD.idempotency_key OR BINARY NEW.content_digest<>BINARY OLD.content_digest OR BINARY NEW.reason<>BINARY OLD.reason OR BINARY NEW.warehouse_code_snapshot<>BINARY OLD.warehouse_code_snapshot OR BINARY NEW.warehouse_name_snapshot<>BINARY OLD.warehouse_name_snapshot OR BINARY NEW.supplier_code_snapshot<>BINARY OLD.supplier_code_snapshot OR BINARY NEW.supplier_name_snapshot<>BINARY OLD.supplier_name_snapshot OR NEW.created_at<>OLD.created_at THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Posted return is immutable and requires lines'; END IF;
        OPEN source_cursor;
        source_loop: LOOP
          FETCH source_cursor INTO movement_id;
          IF finished=1 THEN LEAVE source_loop; END IF;
          SELECT quantity INTO source_qty FROM stock_movements WHERE company_id=OLD.company_id AND id=movement_id AND stock_receipt_id=OLD.stock_receipt_id FOR UPDATE;
          SELECT COALESCE(SUM(quantity),0) INTO used_qty FROM stock_return_lines WHERE company_id=OLD.company_id AND stock_movement_id=movement_id FOR UPDATE;
          IF source_qty IS NULL OR used_qty>source_qty THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Returned quantity exceeds original movement'; END IF;
        END LOOP;
        CLOSE source_cursor;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER stock_return_line_insert_guard BEFORE INSERT ON stock_return_lines FOR EACH ROW
      BEGIN
        DECLARE parent_state VARCHAR(20);
        DECLARE source_qty DECIMAL(9,3);
        DECLARE source_code VARCHAR(40);
        DECLARE source_name VARCHAR(200);
        DECLARE source_unit VARCHAR(30);
        SELECT status INTO parent_state FROM stock_returns WHERE company_id=NEW.company_id AND id=NEW.stock_return_id FOR UPDATE;
        SELECT quantity,item_code_snapshot,item_name_snapshot,unit INTO source_qty,source_code,source_name,source_unit FROM stock_movements
          WHERE company_id=NEW.company_id AND stock_receipt_id=NEW.stock_receipt_id AND id=NEW.stock_movement_id AND warehouse_id=NEW.warehouse_id AND stock_item_id=NEW.stock_item_id FOR UPDATE;
        IF parent_state IS NULL OR parent_state<>'posting' OR source_qty IS NULL OR NEW.quantity>source_qty OR BINARY NEW.item_code_snapshot<>BINARY source_code OR BINARY NEW.item_name_snapshot<>BINARY source_name OR BINARY NEW.unit<>BINARY source_unit THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Return line must match original movement'; END IF;
      END
    SQL
    { stock_returns: %w[delete], stock_return_lines: %w[update delete] }.each do |table, operations|
      operations.each do |operation|
        name = table == :stock_returns ? "stock_return" : "stock_return_line"
        execute "CREATE TRIGGER #{name}_#{operation}_guard BEFORE #{operation.upcase} ON #{table} FOR EACH ROW BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Supplier return ledger is immutable'; END"
      end
    end
  end
  def permissions
    now = connection.quote(Time.current)
    { "inventory.returns.read" => "Xem phiếu trả nhà cung cấp", "inventory.returns.post" => "Ghi sổ trả nhà cung cấp" }.each do |key, name|
      quoted = connection.quote(key)
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{quoted},#{connection.quote(name)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{quoted})"
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{quoted} WHERE r.`key` IN ('admin','manager') AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
end
