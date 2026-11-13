class CreateStockReturnReversals < ActiveRecord::Migration[8.1]
  def up
    add_index :stock_return_lines, [ :company_id, :stock_return_id, :stock_receipt_id, :warehouse_id, :stock_item_id, :stock_movement_id, :id ], unique: true, name: "return_line_reversal_identity"
    create_table :stock_return_reversals do |t|
      t.bigint :company_id, null: false
      t.bigint :stock_return_id, null: false
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

    add_index :stock_return_reversals, [ :company_id, :stock_return_id ], unique: true, name: "return_reversal_once"
    add_index :stock_return_reversals, [ :company_id, :idempotency_key ], unique: true, name: "return_reversal_idempotency"
    add_index :stock_return_reversals, [ :company_id, :code ], unique: true, name: "return_reversal_code"
    add_index :stock_return_reversals, [ :company_id, :stock_return_id, :stock_receipt_id, :warehouse_id, :id ], unique: true, name: "return_reversal_source_identity"
    add_foreign_key :stock_return_reversals, :stock_returns, column: [ :company_id, :stock_receipt_id, :warehouse_id, :stock_return_id ], primary_key: [ :company_id, :stock_receipt_id, :warehouse_id, :id ], name: "return_reversal_source_company"
    add_foreign_key :stock_return_reversals, :users, column: [ :company_id, :posted_by_id ], primary_key: [ :company_id, :id ], name: "return_reversal_actor_company"
    add_check_constraint :stock_return_reversals, "(status='posting' AND posted_at IS NULL) OR (status='posted' AND posted_at IS NOT NULL)", name: "return_reversal_state"
    create_table :stock_return_reversal_lines do |t|
      t.bigint :company_id, null: false
      t.bigint :stock_return_reversal_id, null: false
      t.bigint :stock_return_line_id, null: false
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

    add_index :stock_return_reversal_lines, :stock_return_line_id, unique: true, name: "return_reversal_line_once"
    add_index :stock_return_reversal_lines, [ :company_id, :stock_receipt_id, :id ], name: "return_reversal_net_totals"
    add_index :stock_return_reversal_lines, [ :company_id, :warehouse_id, :stock_item_id, :id ], name: "return_reversal_balance_ledger"
    add_foreign_key :stock_return_reversal_lines, :stock_return_reversals, column: [ :company_id, :stock_return_id, :stock_receipt_id, :warehouse_id, :stock_return_reversal_id ], primary_key: [ :company_id, :stock_return_id, :stock_receipt_id, :warehouse_id, :id ], name: "return_reversal_line_parent"
    add_foreign_key :stock_return_reversal_lines, :stock_return_lines, column: [ :company_id, :stock_return_id, :stock_receipt_id, :warehouse_id, :stock_item_id, :stock_movement_id, :stock_return_line_id ], primary_key: [ :company_id, :stock_return_id, :stock_receipt_id, :warehouse_id, :stock_item_id, :stock_movement_id, :id ], name: "return_reversal_line_source"
    add_check_constraint :stock_return_reversal_lines, "quantity>0", name: "return_reversal_line_positive"
    guards
    execute "DROP TRIGGER stock_return_update_guard"
    net_return_guard
    permissions
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve return reversal ledger"
  end
  private
  def guards
    execute <<~SQL.squish
      CREATE TRIGGER return_reversal_insert_guard BEFORE INSERT ON stock_return_reversals FOR EACH ROW
      BEGIN
        DECLARE receipt_state VARCHAR(20);
        DECLARE source_state VARCHAR(20);
        DECLARE source_supplier BIGINT;
        DECLARE warehouse_code VARCHAR(40);
        DECLARE warehouse_name VARCHAR(200);
        DECLARE supplier_code VARCHAR(40);
        DECLARE supplier_name VARCHAR(200);
        SELECT status INTO receipt_state FROM stock_receipts WHERE company_id=NEW.company_id AND warehouse_id=NEW.warehouse_id AND id=NEW.stock_receipt_id FOR UPDATE;
        SELECT status,supplier_id,warehouse_code_snapshot,warehouse_name_snapshot,supplier_code_snapshot,supplier_name_snapshot INTO source_state,source_supplier,warehouse_code,warehouse_name,supplier_code,supplier_name FROM stock_returns WHERE company_id=NEW.company_id AND stock_receipt_id=NEW.stock_receipt_id AND warehouse_id=NEW.warehouse_id AND id=NEW.stock_return_id FOR UPDATE;
        IF receipt_state IS NULL OR receipt_state<>'posted' OR source_state IS NULL OR source_state<>'posted' OR NEW.status<>'posting' OR NEW.posted_at IS NOT NULL OR NEW.supplier_id<>source_supplier OR BINARY NEW.warehouse_code_snapshot<>BINARY warehouse_code OR BINARY NEW.warehouse_name_snapshot<>BINARY warehouse_name OR BINARY NEW.supplier_code_snapshot<>BINARY supplier_code OR BINARY NEW.supplier_name_snapshot<>BINARY supplier_name THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reversal requires immutable posted return source'; END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER return_reversal_update_guard BEFORE UPDATE ON stock_return_reversals FOR EACH ROW
      BEGIN
        DECLARE receipt_state VARCHAR(20);
        DECLARE source_state VARCHAR(20);
        DECLARE expected_count INT;
        DECLARE actual_count INT;
        SELECT status INTO receipt_state FROM stock_receipts WHERE company_id=OLD.company_id AND id=OLD.stock_receipt_id FOR UPDATE;
        SELECT status INTO source_state FROM stock_returns WHERE company_id=OLD.company_id AND id=OLD.stock_return_id FOR UPDATE;
        SELECT COUNT(*) INTO expected_count FROM stock_return_lines WHERE company_id=OLD.company_id AND stock_return_id=OLD.stock_return_id FOR UPDATE;
        SELECT COUNT(*) INTO actual_count FROM stock_return_reversal_lines WHERE company_id=OLD.company_id AND stock_return_reversal_id=OLD.id FOR UPDATE;
        IF OLD.status<>'posting' OR NEW.status<>'posted' OR NEW.posted_at IS NULL OR source_state IS NULL OR source_state<>'posted' OR receipt_state<>'posted' OR actual_count<1 OR actual_count<>expected_count OR NEW.id<>OLD.id OR NEW.company_id<>OLD.company_id OR NEW.stock_return_id<>OLD.stock_return_id OR NEW.stock_receipt_id<>OLD.stock_receipt_id OR NEW.warehouse_id<>OLD.warehouse_id OR NEW.supplier_id<>OLD.supplier_id OR NEW.posted_by_id<>OLD.posted_by_id OR BINARY NEW.code<>BINARY OLD.code OR BINARY NEW.idempotency_key<>BINARY OLD.idempotency_key OR BINARY NEW.content_digest<>BINARY OLD.content_digest OR BINARY NEW.reason<>BINARY OLD.reason OR BINARY NEW.warehouse_code_snapshot<>BINARY OLD.warehouse_code_snapshot OR BINARY NEW.warehouse_name_snapshot<>BINARY OLD.warehouse_name_snapshot OR BINARY NEW.supplier_code_snapshot<>BINARY OLD.supplier_code_snapshot OR BINARY NEW.supplier_name_snapshot<>BINARY OLD.supplier_name_snapshot OR NEW.created_at<>OLD.created_at THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reversal seal requires all exact source lines and immutable header'; END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER return_reversal_line_insert_guard BEFORE INSERT ON stock_return_reversal_lines FOR EACH ROW
      BEGIN
        DECLARE receipt_state VARCHAR(20);
        DECLARE parent_state VARCHAR(20);
        DECLARE source_qty DECIMAL(9,3);
        DECLARE source_code VARCHAR(40);
        DECLARE source_name VARCHAR(200);
        DECLARE source_unit VARCHAR(30);
        SELECT status INTO receipt_state FROM stock_receipts WHERE company_id=NEW.company_id AND id=NEW.stock_receipt_id FOR UPDATE;
        SELECT status INTO parent_state FROM stock_return_reversals WHERE company_id=NEW.company_id AND id=NEW.stock_return_reversal_id FOR UPDATE;
        SELECT quantity,item_code_snapshot,item_name_snapshot,unit INTO source_qty,source_code,source_name,source_unit FROM stock_return_lines WHERE company_id=NEW.company_id AND stock_return_id=NEW.stock_return_id AND stock_receipt_id=NEW.stock_receipt_id AND warehouse_id=NEW.warehouse_id AND stock_item_id=NEW.stock_item_id AND stock_movement_id=NEW.stock_movement_id AND id=NEW.stock_return_line_id FOR UPDATE;
        IF parent_state IS NULL OR parent_state<>'posting' OR source_qty IS NULL OR NEW.quantity<>source_qty OR BINARY NEW.item_code_snapshot<>BINARY source_code OR BINARY NEW.item_name_snapshot<>BINARY source_name OR BINARY NEW.unit<>BINARY source_unit THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reversal line must exactly match return line'; END IF;
      END
    SQL
    { stock_return_reversals: %w[delete], stock_return_reversal_lines: %w[update delete] }.each do |table, operations|
      operations.each do |operation|
        name = table == :stock_return_reversals ? "return_reversal" : "return_reversal_line"
        execute "CREATE TRIGGER #{name}_#{operation}_guard BEFORE #{operation.upcase} ON #{table} FOR EACH ROW BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Return reversal ledger is immutable'; END"
      end
    end
  end
  def net_return_guard
    execute <<~SQL.squish
      CREATE TRIGGER stock_return_update_guard BEFORE UPDATE ON stock_returns FOR EACH ROW
      BEGIN
        DECLARE finished INT DEFAULT 0;
        DECLARE movement_id BIGINT;
        DECLARE source_qty DECIMAL(9,3);
        DECLARE used_qty DECIMAL(18,3);
        DECLARE reversed_qty DECIMAL(18,3);
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
          SELECT COALESCE(SUM(l.quantity),0) INTO reversed_qty FROM stock_return_reversal_lines l INNER JOIN stock_return_reversals h ON h.company_id=l.company_id AND h.id=l.stock_return_reversal_id WHERE l.company_id=OLD.company_id AND l.stock_movement_id=movement_id AND h.status='posted' FOR UPDATE;
          IF source_qty IS NULL OR used_qty-reversed_qty>source_qty THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Returned quantity exceeds original movement'; END IF;
        END LOOP;
        CLOSE source_cursor;
      END
    SQL
  end
  def permissions
    now = connection.quote(Time.current)
    { "inventory.return_reversals.read" => "Xem đảo phiếu trả", "inventory.return_reversals.post" => "Ghi sổ đảo phiếu trả" }.each do |key, name|
      quoted = connection.quote(key)
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{quoted},#{connection.quote(name)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{quoted})"
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{quoted} WHERE r.`key` IN ('admin','manager') AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
end
