class CreatePurchaseOrders < ActiveRecord::Migration[8.1]
  def up
    create_table :procurement_suppliers do |t|
      t.references :company, null: false, foreign_key: true
      t.string :code, limit: 40, null: false
      t.string :name, limit: 200, null: false
      t.string :status, limit: 20, null: false, default: "active"
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :procurement_suppliers, [ :company_id, :code ], unique: true, name: "supplier_company_code"
    add_index :procurement_suppliers, [ :company_id, :id ], unique: true, name: "supplier_company_identity"
    add_check_constraint :procurement_suppliers, "status IN ('active','inactive')", name: "supplier_state"
    create_table :purchase_orders do |t|
      t.bigint :company_id, null: false
      t.bigint :purchase_request_id, null: false
      t.bigint :supplier_id, null: false
      t.bigint :created_by_id, null: false
      t.bigint :issued_by_id
      t.string :code, limit: 32, null: false
      t.string :status, limit: 20, null: false, default: "draft"
      t.string :currency, limit: 3, null: false, default: "VND"
      t.string :supplier_code_snapshot, limit: 40, null: false
      t.string :supplier_name_snapshot, limit: 200, null: false
      t.string :request_code_snapshot, limit: 32, null: false
      t.string :title_snapshot, limit: 200, null: false
      t.decimal :request_total_snapshot, precision: 18, scale: 0, null: false
      t.decimal :ordered_total, precision: 18, scale: 0, null: false
      t.date :expected_on, null: false
      t.text :price_change_reason
      t.datetime :issued_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :purchase_orders, [ :company_id, :purchase_request_id ], unique: true, name: "one_order_per_company_request"
    add_index :purchase_orders, [ :company_id, :purchase_request_id, :id ], unique: true, name: "order_company_source_identity"
    add_index :purchase_orders, [ :company_id, :id ], unique: true, name: "order_company_identity"
    add_index :purchase_orders, [ :company_id, :code ], unique: true, name: "order_company_code"
    add_index :purchase_orders, [ :company_id, :status, :id ], name: "order_company_queue"
    add_foreign_key :purchase_orders, :purchase_requests, column: [ :company_id, :purchase_request_id ], primary_key: [ :company_id, :id ], name: "order_request_company"
    add_foreign_key :purchase_orders, :procurement_suppliers, column: [ :company_id, :supplier_id ], primary_key: [ :company_id, :id ], name: "order_supplier_company"
    add_foreign_key :purchase_orders, :users, column: [ :company_id, :created_by_id ], primary_key: [ :company_id, :id ], name: "order_creator_company"
    add_foreign_key :purchase_orders, :users, column: [ :company_id, :issued_by_id ], primary_key: [ :company_id, :id ], name: "order_issuer_company"
    add_check_constraint :purchase_orders, "currency='VND' AND request_total_snapshot>=0 AND ordered_total>=0", name: "order_money"
    add_check_constraint :purchase_orders, "(status='draft' AND issued_at IS NULL AND issued_by_id IS NULL) OR (status='issued' AND issued_at IS NOT NULL AND issued_by_id IS NOT NULL)", name: "order_state"
    add_index :purchase_request_lines, [ :company_id, :purchase_request_id, :id ], unique: true, name: "request_line_company_source_identity"
    create_table :purchase_order_lines do |t|
      t.bigint :company_id, null: false
      t.bigint :purchase_order_id, null: false
      t.bigint :purchase_request_id, null: false
      t.bigint :source_line_id, null: false
      t.integer :position, null: false
      t.string :description, limit: 500, null: false
      t.string :unit, limit: 30, null: false
      t.decimal :quantity, precision: 9, scale: 3, null: false
      t.decimal :source_unit_price, precision: 12, scale: 0, null: false
      t.decimal :unit_price, precision: 12, scale: 0, null: false
      t.decimal :line_total, precision: 18, scale: 0, null: false
      t.timestamps
    end
    add_index :purchase_order_lines, [ :purchase_order_id, :source_line_id ], unique: true, name: "order_unique_source_line"
    add_foreign_key :purchase_order_lines, :purchase_orders, column: [ :company_id, :purchase_request_id, :purchase_order_id ], primary_key: [ :company_id, :purchase_request_id, :id ], on_delete: :cascade, name: "order_line_parent_company_source"
    add_foreign_key :purchase_order_lines, :purchase_request_lines, column: [ :company_id, :purchase_request_id, :source_line_id ], primary_key: [ :company_id, :purchase_request_id, :id ], name: "order_line_original_company_source"
    add_check_constraint :purchase_order_lines, "quantity>0 AND source_unit_price>=0 AND unit_price>=0 AND line_total=ROUND(quantity*unit_price,0) AND position BETWEEN 1 AND 50", name: "order_line_money"
    create_table :purchase_order_events do |t|
      t.bigint :company_id, null: false
      t.bigint :purchase_order_id, null: false
      t.bigint :actor_id, null: false
      t.string :action, limit: 20, null: false
      t.integer :version, null: false
      t.text :note
      t.timestamps
    end
    add_index :purchase_order_events, [ :purchase_order_id, :version ], unique: true, name: "order_history_version"
    add_foreign_key :purchase_order_events, :purchase_orders, column: [ :company_id, :purchase_order_id ], primary_key: [ :company_id, :id ], name: "order_history_company_source"
    add_foreign_key :purchase_order_events, :users, column: [ :company_id, :actor_id ], primary_key: [ :company_id, :id ], name: "order_history_actor_company"
    add_check_constraint :purchase_order_events, "version>=0 AND action IN ('created','updated','issued')", name: "order_history_action"
    create_guards
    install_permissions
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve issued orders and supplier history"
  end
  private
  def create_guards
    execute <<~SQL.squish
      CREATE TRIGGER supplier_identity_guard BEFORE UPDATE ON procurement_suppliers FOR EACH ROW
      BEGIN
        IF NEW.company_id<>OLD.company_id THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Supplier company is immutable'; END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER purchase_order_insert_guard BEFORE INSERT ON purchase_orders FOR EACH ROW
      BEGIN
        DECLARE request_state VARCHAR(20);
        DECLARE source_total DECIMAL(18,0);
        DECLARE source_code VARCHAR(32);
        DECLARE source_title VARCHAR(200);
        DECLARE supplier_state VARCHAR(20);
        DECLARE vendor_code VARCHAR(40);
        DECLARE vendor_name VARCHAR(200);
        SELECT status,estimated_total,code,title INTO request_state,source_total,source_code,source_title FROM purchase_requests WHERE company_id=NEW.company_id AND id=NEW.purchase_request_id FOR UPDATE;
        SELECT status,code,name INTO supplier_state,vendor_code,vendor_name FROM procurement_suppliers WHERE company_id=NEW.company_id AND id=NEW.supplier_id FOR UPDATE;
        IF NEW.status<>'draft' OR request_state IS NULL OR request_state<>'approved' OR supplier_state IS NULL OR supplier_state<>'active' OR NOT(NEW.request_total_snapshot<=>source_total) OR NOT(NEW.ordered_total<=>source_total) OR NOT(NEW.request_code_snapshot<=>source_code) OR NOT(NEW.title_snapshot<=>source_title) OR NOT(NEW.supplier_code_snapshot<=>vendor_code) OR NOT(NEW.supplier_name_snapshot<=>vendor_name) THEN
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='PO requires approved source and active same-company supplier snapshots';
        END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER purchase_order_update_guard BEFORE UPDATE ON purchase_orders FOR EACH ROW
      BEGIN
        DECLARE item_count INT;
        DECLARE source_count INT;
        DECLARE changed_prices INT;
        DECLARE item_total DECIMAL(20,0);
        DECLARE supplier_state VARCHAR(20);
        IF OLD.status='issued' OR NEW.status NOT IN ('draft','issued') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Issued PO is immutable'; END IF;
        IF NEW.company_id<>OLD.company_id OR NEW.purchase_request_id<>OLD.purchase_request_id OR NEW.supplier_id<>OLD.supplier_id OR NEW.created_by_id<>OLD.created_by_id OR NEW.code<>OLD.code OR NEW.currency<>OLD.currency OR NEW.supplier_code_snapshot<>OLD.supplier_code_snapshot OR NEW.supplier_name_snapshot<>OLD.supplier_name_snapshot OR NEW.request_code_snapshot<>OLD.request_code_snapshot OR NEW.title_snapshot<>OLD.title_snapshot OR NEW.request_total_snapshot<>OLD.request_total_snapshot THEN
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='PO source and snapshots are immutable';
        END IF;
        IF NEW.status='issued' THEN
          SELECT status INTO supplier_state FROM procurement_suppliers WHERE company_id=OLD.company_id AND id=OLD.supplier_id FOR UPDATE;
          SELECT COUNT(*),COALESCE(SUM(line_total),0),COALESCE(SUM(unit_price<>source_unit_price),0) INTO item_count,item_total,changed_prices FROM purchase_order_lines WHERE company_id=OLD.company_id AND purchase_order_id=OLD.id FOR UPDATE;
          SELECT COUNT(*) INTO source_count FROM purchase_request_lines WHERE company_id=OLD.company_id AND purchase_request_id=OLD.purchase_request_id FOR UPDATE;
          IF supplier_state<>'active' OR item_count<1 OR item_count<>source_count OR item_total<>NEW.ordered_total OR (changed_prices>0 AND NEW.price_change_reason IS NULL) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='PO issue requires active supplier exact lines total and price reason';
          END IF;
        END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER purchase_order_line_insert_guard BEFORE INSERT ON purchase_order_lines FOR EACH ROW
      BEGIN
        DECLARE parent_state VARCHAR(20);
        DECLARE source_matches INT;
        SELECT status INTO parent_state FROM purchase_orders WHERE company_id=NEW.company_id AND id=NEW.purchase_order_id FOR UPDATE;
        IF parent_state IS NULL OR parent_state<>'draft' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only draft PO lines can change'; END IF;
      #{'  '}
        SELECT COUNT(*) INTO source_matches FROM purchase_request_lines WHERE company_id=NEW.company_id AND purchase_request_id=NEW.purchase_request_id AND id=NEW.source_line_id AND position=NEW.position AND description=NEW.description AND unit=NEW.unit AND quantity=NEW.quantity AND estimated_unit_price=NEW.source_unit_price FOR UPDATE; IF source_matches<>1 OR NEW.unit_price<>NEW.source_unit_price THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='PO line must snapshot approved source'; END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER purchase_order_line_update_guard BEFORE UPDATE ON purchase_order_lines FOR EACH ROW
      BEGIN
        DECLARE parent_state VARCHAR(20);
        DECLARE source_matches INT;
        SELECT status INTO parent_state FROM purchase_orders WHERE company_id=OLD.company_id AND id=OLD.purchase_order_id FOR UPDATE;
        IF parent_state IS NULL OR parent_state<>'draft' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only draft PO lines can change'; END IF;
        IF NEW.company_id<>OLD.company_id OR NEW.purchase_order_id<>OLD.purchase_order_id OR NEW.purchase_request_id<>OLD.purchase_request_id OR NEW.source_line_id<>OLD.source_line_id OR NEW.position<>OLD.position OR NEW.description<>OLD.description OR NEW.unit<>OLD.unit OR NEW.quantity<>OLD.quantity OR NEW.source_unit_price<>OLD.source_unit_price THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='PO line source snapshot is immutable'; END IF;
      #{'  '}
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER purchase_order_line_delete_guard BEFORE DELETE ON purchase_order_lines FOR EACH ROW
      BEGIN
        DECLARE parent_state VARCHAR(20);
        DECLARE source_matches INT;
        SELECT status INTO parent_state FROM purchase_orders WHERE company_id=OLD.company_id AND id=OLD.purchase_order_id FOR UPDATE;
        IF parent_state IS NULL OR parent_state<>'draft' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only draft PO lines can change'; END IF;
      #{'  '}
      #{'  '}
      END
    SQL
  end
  def install_permissions
    # Provision only; runtime decisions always read persisted grants and denies.
    definitions = {
      "procurement.suppliers.read" => "Xem nhà cung cấp", "procurement.suppliers.create" => "Tạo nhà cung cấp", "procurement.suppliers.update" => "Sửa nhà cung cấp",
      "procurement.orders.read" => "Xem đơn mua hàng", "procurement.orders.create" => "Lập PO từ phiếu đã duyệt", "procurement.orders.update" => "Sửa PO nháp", "procurement.orders.issue" => "Phát hành PO"
    }
    now = connection.quote(Time.current)
    definitions.each do |key, description|
      quoted = connection.quote(key)
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{quoted},#{connection.quote(description)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{quoted})"
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{quoted} WHERE r.`key` IN ('admin','manager') AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
end
