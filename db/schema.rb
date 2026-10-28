# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_28_000002) do
  create_table "api_tokens", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["digest"], name: "index_api_tokens_on_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "attendances", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.date "work_date", null: false
    t.datetime "checked_in_at", null: false
    t.datetime "checked_out_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id", "employee_id"], name: "fk_tenant_attendances_employee_id"
    t.index ["company_id"], name: "index_attendances_on_company_id"
    t.index ["employee_id", "work_date"], name: "index_attendances_on_employee_id_and_work_date", unique: true
    t.index ["employee_id"], name: "index_attendances_on_employee_id"
  end

  create_table "audit_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["company_id", "actor_id"], name: "fk_tenant_audit_logs_actor_id"
    t.index ["company_id"], name: "index_audit_logs_on_company_id"
  end

  create_table "candidates", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "full_name", null: false
    t.string "email", null: false
    t.string "position", null: false
    t.string "stage", default: "applied", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id"], name: "index_candidates_on_company_id"
  end

  create_table "companies", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_companies_on_code", unique: true
  end

  create_table "company_roles", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "key"], name: "index_company_roles_on_company_id_and_key", unique: true
    t.index ["company_id"], name: "index_company_roles_on_company_id"
  end

  create_table "departments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id", "code"], name: "index_departments_on_company_id_and_code", unique: true
    t.index ["company_id", "id"], name: "index_departments_on_company_id_and_id", unique: true
    t.index ["company_id"], name: "index_departments_on_company_id"
  end

  create_table "employees", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "department_id", null: false
    t.bigint "user_id"
    t.string "employee_code", null: false
    t.string "full_name", null: false
    t.string "email", null: false
    t.string "job_title", null: false
    t.date "hired_on", null: false
    t.string "status", default: "active", null: false
    t.bigint "salary_cents", default: 0, null: false
    t.decimal "annual_leave_days", precision: 5, scale: 1, default: "12.0", null: false
    t.text "bank_account"
    t.text "national_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id", "department_id"], name: "fk_tenant_employees_department_id"
    t.index ["company_id", "email"], name: "index_employees_on_company_id_and_email", unique: true
    t.index ["company_id", "employee_code"], name: "index_employees_on_company_id_and_employee_code", unique: true
    t.index ["company_id", "id"], name: "index_employees_on_company_id_and_id", unique: true
    t.index ["company_id", "user_id"], name: "fk_tenant_employees_user_id"
    t.index ["company_id"], name: "index_employees_on_company_id"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["user_id"], name: "index_employees_on_user_id", unique: true
    t.check_constraint "`salary_cents` >= 0", name: "positive_salary"
  end

  create_table "leave_requests", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.text "reason", null: false
    t.string "status", default: "pending", null: false
    t.bigint "reviewer_id"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id", "employee_id"], name: "fk_tenant_leave_requests_employee_id"
    t.index ["company_id", "reviewer_id"], name: "fk_tenant_leave_requests_reviewer_id"
    t.index ["company_id"], name: "index_leave_requests_on_company_id"
    t.index ["employee_id", "starts_on", "ends_on"], name: "index_leave_requests_on_employee_id_and_starts_on_and_ends_on"
    t.index ["employee_id"], name: "index_leave_requests_on_employee_id"
    t.index ["reviewer_id"], name: "index_leave_requests_on_reviewer_id"
  end

  create_table "outbox_events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "event_type", null: false
    t.json "payload", null: false
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id"], name: "index_outbox_events_on_company_id"
    t.index ["delivered_at", "id"], name: "index_outbox_events_on_delivered_at_and_id"
  end

  create_table "pay_runs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.date "period", null: false
    t.string "status", default: "draft", null: false
    t.bigint "created_by_id", null: false
    t.datetime "finalized_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id", "created_by_id"], name: "fk_tenant_pay_runs_created_by_id"
    t.index ["company_id", "id"], name: "index_pay_runs_on_company_id_and_id", unique: true
    t.index ["company_id", "period"], name: "index_pay_runs_on_company_id_and_period", unique: true
    t.index ["company_id"], name: "index_pay_runs_on_company_id"
    t.index ["created_by_id"], name: "index_pay_runs_on_created_by_id"
  end

  create_table "payslips", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "pay_run_id", null: false
    t.bigint "employee_id", null: false
    t.bigint "gross_cents", null: false
    t.bigint "deductions_cents", default: 0, null: false
    t.bigint "net_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id", "employee_id"], name: "fk_tenant_payslips_employee_id"
    t.index ["company_id", "pay_run_id"], name: "fk_tenant_payslips_pay_run_id"
    t.index ["company_id"], name: "index_payslips_on_company_id"
    t.index ["employee_id"], name: "index_payslips_on_employee_id"
    t.index ["pay_run_id", "employee_id"], name: "index_payslips_on_pay_run_id_and_employee_id", unique: true
    t.index ["pay_run_id"], name: "index_payslips_on_pay_run_id"
  end

  create_table "permissions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
  end

  create_table "role_permissions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "company_role_id", null: false
    t.bigint "permission_id", null: false
    t.index ["company_role_id", "permission_id"], name: "idx_role_permission_unique", unique: true
    t.index ["company_role_id"], name: "index_role_permissions_on_company_role_id"
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
  end

  create_table "user_permissions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "permission_id", null: false
    t.boolean "granted", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_user_permissions_on_permission_id"
    t.index ["user_id", "permission_id"], name: "index_user_permissions_on_user_id_and_permission_id", unique: true
    t.index ["user_id"], name: "index_user_permissions_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "employee", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id", null: false
    t.index ["company_id", "id"], name: "index_users_on_company_id_and_id", unique: true
    t.index ["company_id", "role"], name: "fk_users_company_role"
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "api_tokens", "users"
  add_foreign_key "attendances", "companies"
  add_foreign_key "attendances", "employees"
  add_foreign_key "attendances", "employees", column: ["company_id", "employee_id"], primary_key: ["company_id", "id"], name: "fk_tenant_attendances_employee_id"
  add_foreign_key "audit_logs", "companies"
  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "audit_logs", "users", column: ["company_id", "actor_id"], primary_key: ["company_id", "id"], name: "fk_tenant_audit_logs_actor_id"
  add_foreign_key "candidates", "companies"
  add_foreign_key "company_roles", "companies"
  add_foreign_key "departments", "companies"
  add_foreign_key "employees", "companies"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "departments", column: ["company_id", "department_id"], primary_key: ["company_id", "id"], name: "fk_tenant_employees_department_id"
  add_foreign_key "employees", "users"
  add_foreign_key "employees", "users", column: ["company_id", "user_id"], primary_key: ["company_id", "id"], name: "fk_tenant_employees_user_id"
  add_foreign_key "leave_requests", "companies"
  add_foreign_key "leave_requests", "employees"
  add_foreign_key "leave_requests", "employees", column: ["company_id", "employee_id"], primary_key: ["company_id", "id"], name: "fk_tenant_leave_requests_employee_id"
  add_foreign_key "leave_requests", "users", column: "reviewer_id"
  add_foreign_key "leave_requests", "users", column: ["company_id", "reviewer_id"], primary_key: ["company_id", "id"], name: "fk_tenant_leave_requests_reviewer_id"
  add_foreign_key "outbox_events", "companies"
  add_foreign_key "pay_runs", "companies"
  add_foreign_key "pay_runs", "users", column: "created_by_id"
  add_foreign_key "pay_runs", "users", column: ["company_id", "created_by_id"], primary_key: ["company_id", "id"], name: "fk_tenant_pay_runs_created_by_id"
  add_foreign_key "payslips", "companies"
  add_foreign_key "payslips", "employees"
  add_foreign_key "payslips", "employees", column: ["company_id", "employee_id"], primary_key: ["company_id", "id"], name: "fk_tenant_payslips_employee_id"
  add_foreign_key "payslips", "pay_runs"
  add_foreign_key "payslips", "pay_runs", column: ["company_id", "pay_run_id"], primary_key: ["company_id", "id"], name: "fk_tenant_payslips_pay_run_id"
  add_foreign_key "role_permissions", "company_roles"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "user_permissions", "permissions"
  add_foreign_key "user_permissions", "users"
  add_foreign_key "users", "companies"
  add_foreign_key "users", "company_roles", column: ["company_id", "role"], primary_key: ["company_id", "key"], name: "fk_users_company_role"
end
