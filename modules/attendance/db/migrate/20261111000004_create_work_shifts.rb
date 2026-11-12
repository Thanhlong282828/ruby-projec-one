class CreateWorkShifts < ActiveRecord::Migration[8.1]
  ACTIONS = { "read" => "Xem ca làm việc", "create" => "Tạo ca làm việc", "update" => "Sửa ca làm việc", "delete" => "Xóa ca làm việc" }.freeze
  def up
    create_table :work_shifts do |t|
      t.references :company, null: false, foreign_key: true
      t.string :code, null: false, limit: 30
      t.string :name, null: false
      t.integer :start_minute, null: false
      t.integer :end_minute, null: false
      t.integer :unpaid_break_minutes, null: false, default: 0
      t.integer :grace_in_minutes, null: false, default: 0
      t.integer :grace_out_minutes, null: false, default: 0
      t.integer :overtime_threshold_minutes, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :work_shifts, [ :company_id, :code ], unique: true
    add_index :work_shifts, [ :company_id, :id ], unique: true
    add_check_constraint :work_shifts, "start_minute BETWEEN 0 AND 1439 AND end_minute BETWEEN 0 AND 1439 AND start_minute <> end_minute", name: "shift_clock_range"
    duration = "(CASE WHEN end_minute > start_minute THEN end_minute-start_minute ELSE end_minute+1440-start_minute END)"
    add_check_constraint :work_shifts, "unpaid_break_minutes >= 0 AND unpaid_break_minutes < #{duration} AND grace_in_minutes BETWEEN 0 AND #{duration} AND grace_out_minutes BETWEEN 0 AND #{duration} AND overtime_threshold_minutes BETWEEN 0 AND #{duration}", name: "shift_rule_range"
    now = connection.quote(Time.current)
    ACTIONS.each do |action, label|
      key = connection.quote("work_shifts.#{action}")
      execute "INSERT INTO permissions (`key`,name,created_at,updated_at) SELECT #{key},#{connection.quote(label)},#{now},#{now} WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE `key`=#{key})"
      roles = action == "read" ? %w[admin hr manager employee] : (action == "delete" ? %w[admin] : %w[admin hr])
      execute "INSERT INTO role_permissions (company_role_id,permission_id) SELECT r.id,p.id FROM company_roles r JOIN permissions p ON p.`key`=#{key} WHERE r.`key` IN (#{roles.map { |role| connection.quote(role) }.join(',')}) AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.company_role_id=r.id AND rp.permission_id=p.id)"
    end
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve shift configuration and role grants; use a reviewed recovery migration"
  end
end
