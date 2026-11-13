ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
raise "Tests may only use hrm_test" unless ActiveRecord::Base.connection_db_config.database == "hrm_test"
ActiveRecord::Migration.check_all_pending!
required_guards = %w[users_membership_insert_guard users_membership_update_guard procurement_request_insert_guard procurement_request_update_guard procurement_line_insert_guard procurement_line_update_guard procurement_line_delete_guard supplier_identity_guard purchase_order_insert_guard purchase_order_update_guard purchase_order_line_insert_guard purchase_order_line_update_guard purchase_order_line_delete_guard goods_receipt_insert_guard goods_receipt_update_guard goods_receipt_delete_guard goods_receipt_line_insert_guard goods_receipt_line_update_guard goods_receipt_line_delete_guard warehouses_identity_guard stock_items_identity_guard stock_receipt_insert_guard stock_receipt_update_guard stock_receipt_delete_guard stock_movement_insert_guard stock_movement_update_guard stock_movement_delete_guard]
guards = ActiveRecord::Base.connection.select_values("SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE()")
raise "Prepare hrm_test with bin/migrate-docker test; required database guards missing" unless (required_guards - guards).empty?
class ActiveSupport::TestCase
  self.use_transactional_tests = true
  setup do
    Current.reset
    Rails.cache.clear
    ActiveJob::Base.queue_adapter = :test
  end
  teardown { Current.reset }
  def fixture_company
    @fixture_company ||= Company.find_or_create_by!(code: "TEST") { |company| company.name = "Test Company" }
  end
  def make_user(role = :employee, company: fixture_company)
    User.create!(company: company, email: "#{SecureRandom.hex(6)}@example.test", password: "StrongPassword123!", role: role)
  end
  def make_employee(user = make_user, **overrides)
    department = Department.find_or_create_by!(company: user.company, code: "TEST") { |d| d.name = "Testing" }
    Employee.create!({ user: user, department: department, employee_code: SecureRandom.hex(4), full_name: "Test Person", email: user.email, job_title: "Engineer", hired_on: Date.current, salary_cents: 20000000 }.merge(overrides))
  end
end
