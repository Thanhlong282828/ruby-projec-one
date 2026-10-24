class CreateHrm < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "employee"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :users, :email, unique: true
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :api_tokens, :digest, unique: true
    create_table :departments do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.timestamps
    end
    add_index :departments, :code, unique: true
    create_table :employees do |t|
      t.references :department, null: false, foreign_key: true
      t.references :user, foreign_key: true, index: { unique: true }
      t.string :employee_code, null: false
      t.string :full_name, null: false
      t.string :email, null: false
      t.string :job_title, null: false
      t.date :hired_on, null: false
      t.string :status, null: false, default: "active"
      t.integer :salary_cents, null: false, default: 0, limit: 8
      t.decimal :annual_leave_days, precision: 5, scale: 1, default: 12, null: false
      t.text :bank_account
      t.text :national_id
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
    add_index :employees, :employee_code, unique: true
    add_index :employees, :email, unique: true
    add_check_constraint :employees, "salary_cents >= 0", name: "positive_salary"
    create_table :leave_requests do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.text :reason, null: false
      t.string :status, null: false, default: "pending"
      t.references :reviewer, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :leave_requests, [:employee_id, :starts_on, :ends_on]
    create_table :attendances do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :work_date, null: false
      t.datetime :checked_in_at, null: false
      t.datetime :checked_out_at
      t.timestamps
    end
    add_index :attendances, [:employee_id, :work_date], unique: true
    create_table :pay_runs do |t|
      t.date :period, null: false
      t.string :status, null: false, default: "draft"
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :finalized_at
      t.timestamps
    end
    add_index :pay_runs, :period, unique: true
    create_table :payslips do |t|
      t.references :pay_run, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.bigint :gross_cents, null: false
      t.bigint :deductions_cents, null: false, default: 0
      t.bigint :net_cents, null: false
      t.timestamps
    end
    add_index :payslips, [:pay_run_id, :employee_id], unique: true
    create_table :candidates do |t|
      t.string :full_name, null: false
      t.string :email, null: false
      t.string :position, null: false
      t.string :stage, null: false, default: "applied"
      t.text :notes
      t.timestamps
    end
    create_table :audit_logs do |t|
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.json :metadata
      t.timestamps
    end
    create_table :outbox_events do |t|
      t.string :event_type, null: false
      t.json :payload, null: false
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :outbox_events, [:delivered_at, :id]
  end
end
