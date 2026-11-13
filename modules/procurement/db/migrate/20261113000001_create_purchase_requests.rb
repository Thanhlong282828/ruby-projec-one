class CreatePurchaseRequests < ActiveRecord::Migration[8.1]
  def up
    create_table :purchase_requests do |t|
      t.references :company, null: false, foreign_key: true
      t.bigint :created_by_id, null: false
      t.bigint :reviewed_by_id
      t.string :code, limit: 32, null: false
      t.string :title, limit: 200, null: false
      t.text :purpose, null: false
      t.date :needed_on, null: false
      t.string :currency, limit: 3, null: false, default: "VND"
      t.decimal :estimated_total, precision: 18, scale: 0, null: false
      t.string :status, limit: 20, null: false, default: "draft"
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.text :rejection_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :purchase_requests, [ :company_id, :id ], unique: true, name: "purchase_request_company_identity"
    add_index :purchase_requests, [ :company_id, :code ], unique: true, name: "purchase_request_company_code"
    add_index :purchase_requests, [ :company_id, :status, :created_by_id, :id ], name: "purchase_request_queue"
    add_foreign_key :purchase_requests, :users, column: [ :company_id, :created_by_id ], primary_key: [ :company_id, :id ], name: "purchase_request_creator_company"
    add_foreign_key :purchase_requests, :users, column: [ :company_id, :reviewed_by_id ], primary_key: [ :company_id, :id ], name: "purchase_request_reviewer_company"
    add_check_constraint :purchase_requests, "currency='VND' AND estimated_total>=0", name: "purchase_request_money"
    add_check_constraint :purchase_requests, "reviewed_by_id IS NULL OR reviewed_by_id<>created_by_id", name: "purchase_request_maker_checker"
    add_check_constraint :purchase_requests, "(status='draft' AND submitted_at IS NULL AND reviewed_at IS NULL AND reviewed_by_id IS NULL AND rejection_reason IS NULL) OR (status='submitted' AND submitted_at IS NOT NULL AND reviewed_at IS NULL AND reviewed_by_id IS NULL AND rejection_reason IS NULL) OR (status='approved' AND submitted_at IS NOT NULL AND reviewed_at IS NOT NULL AND reviewed_by_id IS NOT NULL AND rejection_reason IS NULL) OR (status='rejected' AND submitted_at IS NOT NULL AND reviewed_at IS NOT NULL AND reviewed_by_id IS NOT NULL AND rejection_reason IS NOT NULL)", name: "purchase_request_state"
    add_check_constraint :purchase_requests, "reviewed_at IS NULL OR reviewed_at>=submitted_at", name: "purchase_request_chronology"
    create_table :purchase_request_lines do |t|
      t.bigint :company_id, null: false
      t.bigint :purchase_request_id, null: false
      t.integer :position, null: false
      t.string :description, limit: 500, null: false
      t.string :unit, limit: 30, null: false
      t.decimal :quantity, precision: 9, scale: 3, null: false
      t.decimal :estimated_unit_price, precision: 12, scale: 0, null: false
      t.decimal :line_total, precision: 18, scale: 0, null: false
      t.timestamps
    end
    add_index :purchase_request_lines, [ :purchase_request_id, :position ], unique: true, name: "purchase_line_position"
    add_foreign_key :purchase_request_lines, :purchase_requests, column: [ :company_id, :purchase_request_id ], primary_key: [ :company_id, :id ], on_delete: :cascade, name: "purchase_line_company_source"
    add_check_constraint :purchase_request_lines, "quantity>0 AND estimated_unit_price>=0 AND line_total=ROUND(quantity*estimated_unit_price,0) AND position BETWEEN 1 AND 50", name: "purchase_line_amount"
    create_table :purchase_request_events do |t|
      t.bigint :company_id, null: false
      t.bigint :purchase_request_id, null: false
      t.bigint :actor_id, null: false
      t.integer :version, null: false
      t.string :action, limit: 20, null: false
      t.string :from_status, limit: 20
      t.string :to_status, limit: 20, null: false
      t.text :note
      t.timestamps
    end
    add_index :purchase_request_events, [ :purchase_request_id, :version ], unique: true, name: "purchase_event_version"
    add_foreign_key :purchase_request_events, :purchase_requests, column: [ :company_id, :purchase_request_id ], primary_key: [ :company_id, :id ], name: "purchase_event_company_source"
    add_foreign_key :purchase_request_events, :users, column: [ :company_id, :actor_id ], primary_key: [ :company_id, :id ], name: "purchase_event_actor_company"
    add_check_constraint :purchase_request_events, "version>=0 AND ((action='created' AND from_status IS NULL AND to_status='draft') OR (action='updated' AND from_status='draft' AND to_status='draft') OR (action='submitted' AND from_status='draft' AND to_status='submitted') OR (action='approved' AND from_status='submitted' AND to_status='approved') OR (action='rejected' AND from_status='submitted' AND to_status='rejected'))", name: "purchase_event_transition"
    create_guards
    install_permissions
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve purchasing history"
  end
  private
  def create_guards
    execute <<~SQL.squish
      CREATE TRIGGER procurement_request_insert_guard BEFORE INSERT ON purchase_requests FOR EACH ROW
      BEGIN
        IF NEW.status <> 'draft' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Purchase requests start as draft'; END IF;
      END
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER procurement_request_update_guard BEFORE UPDATE ON purchase_requests FOR EACH ROW
      BEGIN
        DECLARE item_count INT;
        DECLARE item_total DECIMAL(20,0);
        IF NEW.company_id<>OLD.company_id OR NEW.created_by_id<>OLD.created_by_id OR NEW.code<>OLD.code OR NEW.currency<>OLD.currency THEN
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Purchase identity is immutable';
        END IF;
        IF OLD.status<>'draft' AND (NOT(NEW.title<=>OLD.title) OR NOT(NEW.purpose<=>OLD.purpose) OR NOT(NEW.needed_on<=>OLD.needed_on) OR NOT(NEW.estimated_total<=>OLD.estimated_total)) THEN
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Submitted purchase content is immutable';
        END IF;
        IF NOT((OLD.status='draft' AND NEW.status IN ('draft','submitted')) OR (OLD.status='submitted' AND NEW.status IN ('approved','rejected'))) THEN
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid purchase transition';
        END IF;
        IF NEW.status='submitted' THEN
          SELECT COUNT(*),COALESCE(SUM(line_total),0) INTO item_count,item_total FROM purchase_request_lines WHERE purchase_request_id=OLD.id AND company_id=OLD.company_id FOR UPDATE;
          IF item_count<1 OR item_count>50 OR item_total<>NEW.estimated_total THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Purchase total does not match lines';
          END IF;
        END IF;
      END
    SQL
    { "insert" => "NEW", "update" => "OLD", "delete" => "OLD" }.each do |event, row|
      # Identifiers are fixed server literals, never request input.
      identity_guard = event == "update" ? "IF NEW.company_id<>OLD.company_id OR NEW.purchase_request_id<>OLD.purchase_request_id OR NEW.position<>OLD.position THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Purchase line identity is immutable'; END IF;" : ""
      execute <<~SQL.squish
        CREATE TRIGGER procurement_line_#{event}_guard BEFORE #{event.upcase} ON purchase_request_lines FOR EACH ROW
        BEGIN
          DECLARE parent_status VARCHAR(20);
          #{identity_guard}
          SELECT status INTO parent_status FROM purchase_requests WHERE id=#{row}.purchase_request_id AND company_id=#{row}.company_id FOR UPDATE;
          IF parent_status IS NULL OR parent_status<>'draft' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Submitted purchase lines are immutable';
          END IF;
        END
      SQL
    end
  end
  def install_permissions
    now = connection.quote(Time.current)
    definitions = {
      "procurement.requests.read" => "Xem yêu cầu mua của mình", "procurement.requests.read_all" => "Xem yêu cầu mua trong công ty",
      "procurement.requests.create" => "Tạo yêu cầu mua", "procurement.requests.update" => "Sửa yêu cầu mua nháp của mình",
      "procurement.requests.submit" => "Gửi yêu cầu mua của mình", "procurement.requests.review" => "Quyết định yêu cầu mua của người khác"
    }
    definitions.each do |key, name|
      quoted = connection.quote(key)
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{quoted},#{connection.quote(name)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{quoted})"
      roles = %w[procurement.requests.read_all procurement.requests.review].include?(key) ? %w[admin manager] : %w[admin manager hr employee]
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{quoted} WHERE r.`key` IN (#{roles.map { |role| connection.quote(role) }.join(',')}) AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
end
