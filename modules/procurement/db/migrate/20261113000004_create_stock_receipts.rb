class CreateStockReceipts < ActiveRecord::Migration[8.1]
  def up
    %i[warehouses stock_items].each do |name|
      create_table name do |t|
        t.references :company, null: false, foreign_key: true
        t.string :code, limit: 40, null: false
        t.string :name, limit: 200, null: false
        t.string :unit, limit: 30, null: false if name == :stock_items
        t.string :status, limit: 20, null: false, default: "active"
        t.integer :lock_version, null: false, default: 0
        t.timestamps
      end
      add_index name, [ :company_id, :code ], unique: true, name: "#{name}_company_code"
      add_index name, [ :company_id, :id ], unique: true, name: "#{name}_company_identity"
      add_check_constraint name, "status IN ('active','inactive')", name: "#{name}_state"
      immutable_unit = name == :stock_items ? "OR BINARY NEW.unit<>BINARY OLD.unit" : ""
      execute "CREATE TRIGGER #{name}_identity_guard BEFORE UPDATE ON #{name} FOR EACH ROW BEGIN IF NEW.company_id<>OLD.company_id OR BINARY NEW.code<>BINARY OLD.code #{immutable_unit} THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Stable catalog identity and unit cannot change'; END IF; END"
    end
    add_index :goods_receipts, [ :company_id, :id ], unique: true, name: "goods_receipt_company_identity"
    add_index :goods_receipt_lines, [ :company_id, :goods_receipt_id, :id, :purchase_order_line_id ], unique: true, name: "goods_receipt_line_stock_identity"
    create_table :stock_receipts do |t|
      t.bigint :company_id, null: false
      t.bigint :goods_receipt_id, null: false
      t.bigint :warehouse_id, null: false
      t.bigint :posted_by_id, null: false
      t.string :code, limit: 32, null: false
      t.string :status, limit: 20, null: false, default: "posting"
      t.string :mapping_digest, limit: 64, null: false
      t.string :warehouse_code_snapshot, limit: 40, null: false
      t.string :warehouse_name_snapshot, limit: 200, null: false
      t.datetime :posted_at
      t.timestamps
    end
    add_index :stock_receipts, [ :company_id, :goods_receipt_id ], unique: true, name: "one_stock_entry_per_receipt"
    add_index :stock_receipts, [ :company_id, :goods_receipt_id, :warehouse_id, :id ], unique: true, name: "stock_entry_source_destination"
    add_index :stock_receipts, [ :company_id, :code ], unique: true, name: "stock_entry_company_code"
    add_foreign_key :stock_receipts, :goods_receipts, column: [ :company_id, :goods_receipt_id ], primary_key: [ :company_id, :id ], on_delete: :cascade, name: "stock_entry_receipt_company"
    add_foreign_key :stock_receipts, :warehouses, column: [ :company_id, :warehouse_id ], primary_key: [ :company_id, :id ], name: "stock_entry_warehouse_company"
    add_foreign_key :stock_receipts, :users, column: [ :company_id, :posted_by_id ], primary_key: [ :company_id, :id ], name: "stock_entry_actor_company"
    add_check_constraint :stock_receipts, "(status='posting' AND posted_at IS NULL) OR (status='posted' AND posted_at IS NOT NULL)", name: "stock_entry_state"
    create_table :stock_movements do |t|
      t.bigint :company_id, null: false
      t.bigint :stock_receipt_id, null: false
      t.bigint :goods_receipt_id, null: false
      t.bigint :goods_receipt_line_id, null: false
      t.bigint :purchase_order_line_id, null: false
      t.bigint :warehouse_id, null: false
      t.bigint :stock_item_id, null: false
      t.string :item_code_snapshot, limit: 40, null: false
      t.string :item_name_snapshot, limit: 200, null: false
      t.string :unit, limit: 30, null: false
      t.decimal :quantity, precision: 9, scale: 3, null: false
      t.timestamps
    end
    add_index :stock_movements, [ :stock_receipt_id, :goods_receipt_line_id ], unique: true, name: "stock_movement_unique_source"
    add_index :stock_movements, [ :company_id, :warehouse_id, :stock_item_id, :id ], name: "stock_balance_ledger"
    add_foreign_key :stock_movements, :stock_receipts, column: [ :company_id, :goods_receipt_id, :warehouse_id, :stock_receipt_id ], primary_key: [ :company_id, :goods_receipt_id, :warehouse_id, :id ], on_delete: :cascade, name: "stock_movement_parent_company"
    add_foreign_key :stock_movements, :goods_receipt_lines, column: [ :company_id, :goods_receipt_id, :goods_receipt_line_id, :purchase_order_line_id ], primary_key: [ :company_id, :goods_receipt_id, :id, :purchase_order_line_id ], on_delete: :cascade, name: "stock_movement_source_company"
    add_foreign_key :stock_movements, :stock_items, column: [ :company_id, :stock_item_id ], primary_key: [ :company_id, :id ], name: "stock_movement_item_company"
    add_check_constraint :stock_movements, "quantity>0", name: "stock_movement_positive"
    guards
    provision_permissions
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve stock ledger"
  end
  private
  def guards
    execute <<~SQL.squish
      CREATE TRIGGER stock_receipt_insert_guard BEFORE INSERT ON stock_receipts FOR EACH ROW
      BEGIN
        DECLARE source_state VARCHAR(20);
        DECLARE destination_state VARCHAR(20);
        DECLARE destination_code VARCHAR(40);
        DECLARE destination_name VARCHAR(200);
        SELECT status INTO source_state FROM goods_receipts WHERE company_id=NEW.company_id AND id=NEW.goods_receipt_id FOR UPDATE;
        SELECT status,code,name INTO destination_state,destination_code,destination_name FROM warehouses WHERE company_id=NEW.company_id AND id=NEW.warehouse_id FOR UPDATE;
        IF source_state IS NULL OR source_state<>'recorded' OR destination_state IS NULL OR destination_state<>'active' OR NEW.status<>'posting' OR BINARY NEW.warehouse_code_snapshot<>BINARY destination_code OR BINARY NEW.warehouse_name_snapshot<>BINARY destination_name THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Stock entry requires recorded receipt and active same-company warehouse'; END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER stock_receipt_update_guard BEFORE UPDATE ON stock_receipts FOR EACH ROW
      BEGIN
        DECLARE source_count INT;
        DECLARE movement_count INT;
        DECLARE inactive_count INT;
        DECLARE destination_state VARCHAR(20);
        SELECT COUNT(*) INTO source_count FROM goods_receipt_lines WHERE company_id=OLD.company_id AND goods_receipt_id=OLD.goods_receipt_id FOR UPDATE;
        SELECT COUNT(*) INTO movement_count FROM stock_movements WHERE company_id=OLD.company_id AND stock_receipt_id=OLD.id FOR UPDATE;
        SELECT COUNT(*) INTO inactive_count FROM stock_movements m INNER JOIN stock_items i ON i.company_id=m.company_id AND i.id=m.stock_item_id WHERE m.company_id=OLD.company_id AND m.stock_receipt_id=OLD.id AND i.status<>'active' FOR UPDATE;
        SELECT status INTO destination_state FROM warehouses WHERE company_id=OLD.company_id AND id=OLD.warehouse_id FOR UPDATE;
        IF OLD.status<>'posting' OR NEW.status<>'posted' OR NEW.posted_at IS NULL OR source_count<1 OR movement_count<>source_count OR inactive_count>0 OR destination_state<>'active' OR NEW.company_id<>OLD.company_id OR NEW.goods_receipt_id<>OLD.goods_receipt_id OR NEW.warehouse_id<>OLD.warehouse_id OR NEW.posted_by_id<>OLD.posted_by_id OR NEW.code<>OLD.code OR NEW.mapping_digest<>OLD.mapping_digest OR BINARY NEW.warehouse_code_snapshot<>BINARY OLD.warehouse_code_snapshot OR BINARY NEW.warehouse_name_snapshot<>BINARY OLD.warehouse_name_snapshot OR NEW.created_at<>OLD.created_at THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Posted entry is immutable and must contain every received line'; END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER stock_movement_insert_guard BEFORE INSERT ON stock_movements FOR EACH ROW
      BEGIN
        DECLARE parent_state VARCHAR(20);
        DECLARE item_state VARCHAR(20);
        DECLARE item_unit VARCHAR(30);
        DECLARE item_code VARCHAR(40);
        DECLARE item_name VARCHAR(200);
        DECLARE source_qty DECIMAL(9,3);
        DECLARE source_unit VARCHAR(30);
        SELECT status INTO parent_state FROM stock_receipts WHERE company_id=NEW.company_id AND id=NEW.stock_receipt_id FOR UPDATE;
        SELECT quantity INTO source_qty FROM goods_receipt_lines WHERE company_id=NEW.company_id AND id=NEW.goods_receipt_line_id AND goods_receipt_id=NEW.goods_receipt_id AND purchase_order_line_id=NEW.purchase_order_line_id FOR UPDATE;
        SELECT unit INTO source_unit FROM purchase_order_lines WHERE company_id=NEW.company_id AND id=NEW.purchase_order_line_id FOR UPDATE;
        SELECT status,unit,code,name INTO item_state,item_unit,item_code,item_name FROM stock_items WHERE company_id=NEW.company_id AND id=NEW.stock_item_id FOR UPDATE;
        IF parent_state IS NULL OR parent_state<>'posting' OR source_qty IS NULL OR NEW.quantity<>source_qty OR item_state IS NULL OR item_state<>'active' OR BINARY item_unit<>BINARY source_unit OR BINARY NEW.unit<>BINARY item_unit OR BINARY NEW.item_code_snapshot<>BINARY item_code OR BINARY NEW.item_name_snapshot<>BINARY item_name THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Movement must match received quantity and active item unit'; END IF;
      END
    SQL
    { stock_receipts: %w[delete], stock_movements: %w[update delete] }.each do |table, operations|
      operations.each do |operation|
        trigger = table == :stock_receipts ? "stock_receipt" : "stock_movement"
        execute "CREATE TRIGGER #{trigger}_#{operation}_guard BEFORE #{operation.upcase} ON #{table} FOR EACH ROW BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Stock ledger is immutable'; END"
      end
    end
  end
  def provision_permissions
    now = connection.quote(Time.current)
    { "inventory.catalog.read" => "Xem kho và mã hàng", "inventory.catalog.manage" => "Quản lý kho và mã hàng", "inventory.receipts.read" => "Xem phiếu nhập kho", "inventory.receipts.post" => "Ghi sổ nhập kho", "inventory.balances.read" => "Xem tồn theo kho" }.each do |key, name|
      quoted = connection.quote(key)
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{quoted},#{connection.quote(name)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{quoted})"
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{quoted} WHERE r.`key` IN ('admin','manager') AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
end
