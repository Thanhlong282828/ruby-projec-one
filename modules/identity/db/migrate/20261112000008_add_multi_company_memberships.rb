class AddMultiCompanyMemberships < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :principal_user_id, :bigint unless column_exists?(:users, :principal_user_id)
    add_foreign_key :users, :users, column: :principal_user_id, name: "membership_principal" unless foreign_key_exists?(:users, :users, name: "membership_principal")
    add_index :users, [ :principal_user_id, :company_id ], unique: true, name: "principal_company_membership" unless index_exists?(:users, [ :principal_user_id, :company_id ], name: "principal_company_membership")
    change_column_null :users, :password_digest, true
    remove_index :users, name: "index_users_on_email" if index_exists?(:users, :email, name: "index_users_on_email")
    add_index :users, [ :company_id, :email ], unique: true unless index_exists?(:users, [ :company_id, :email ], unique: true)
    add_column :users, :login_email, :string, as: "CASE WHEN principal_user_id IS NULL THEN email ELSE NULL END", stored: true unless column_exists?(:users, :login_email)
    add_index :users, :login_email, unique: true unless index_exists?(:users, :login_email, unique: true)
    add_check_constraint :users, "(principal_user_id IS NULL AND password_digest IS NOT NULL) OR (principal_user_id IS NOT NULL AND password_digest IS NULL)", name: "principal_owns_credentials" unless check_constraint_exists?(:users, name: "principal_owns_credentials")
    # AFTER INSERT sees the real AUTO_INCREMENT ID; BEFORE INSERT only sees 0.
    # SIGNAL rolls the statement back without weakening the other constraints.
    install_membership_triggers
    [ :login_sessions, :api_tokens ].each do |table|
      add_column table, :principal_user_id, :bigint unless column_exists?(table, :principal_user_id)
      execute "UPDATE #{table} SET principal_user_id = user_id WHERE principal_user_id IS NULL"
      change_column_null table, :principal_user_id, false
      add_foreign_key table, :users, column: :principal_user_id unless foreign_key_exists?(table, :users, column: :principal_user_id)
      add_index table, :principal_user_id unless index_exists?(table, :principal_user_id)
    end
    add_column :companies, :lock_version, :integer, null: false, default: 0 unless column_exists?(:companies, :lock_version)
    create_table :system_grants, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.timestamps
    end
    add_index :system_grants, [ :user_id, :permission_id ], unique: true unless index_exists?(:system_grants, [ :user_id, :permission_id ], unique: true)
    create_table :system_audit_logs, if_not_exists: true do |t|
      t.references :principal_user, null: false, foreign_key: { to_table: :users }
      t.references :company, null: false, foreign_key: true
      t.string :action, null: false, limit: 60
      t.string :record_type, null: false, limit: 40
      t.bigint :record_id, null: false
      t.timestamps
    end
    add_index :system_audit_logs, [ :company_id, :id ] unless index_exists?(:system_audit_logs, [ :company_id, :id ])
    now = connection.quote(Time.current)
    { "read" => "Xem danh mục công ty toàn hệ thống", "manage" => "Quản lý công ty và memberships toàn hệ thống" }.each do |suffix, name|
      key = connection.quote("system.companies.#{suffix}")
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{key},#{connection.quote(name)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{key})"
    end
  end
  private
  def install_membership_triggers
    existing = connection.select_values("SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = DATABASE()")
    unless existing.include?("users_membership_insert_guard")
      execute <<~SQL.squish
        CREATE TRIGGER users_membership_insert_guard AFTER INSERT ON users FOR EACH ROW
        BEGIN
          IF NEW.principal_user_id IS NOT NULL THEN
            IF NEW.principal_user_id = NEW.id THEN
              SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'membership must not reference itself';
            END IF;
            IF NOT EXISTS (SELECT 1 FROM users p WHERE p.id = NEW.principal_user_id AND p.principal_user_id IS NULL AND p.company_id <> NEW.company_id) THEN
              SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'membership requires a root identity in another company';
            END IF;
          END IF;
        END
      SQL
    end
    unless existing.include?("users_membership_update_guard")
      execute <<~SQL.squish
        CREATE TRIGGER users_membership_update_guard BEFORE UPDATE ON users FOR EACH ROW
        BEGIN
          IF NEW.id <> OLD.id OR NOT (NEW.principal_user_id <=> OLD.principal_user_id) OR NEW.company_id <> OLD.company_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'identity and company are immutable; create a membership';
          END IF;
        END
      SQL
    end
  end
  public
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve identities, memberships and tenant history"
  end
end
