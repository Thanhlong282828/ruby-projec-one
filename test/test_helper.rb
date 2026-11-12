ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
raise "Tests may only use hrm_test" unless ActiveRecord::Base.connection_db_config.database == "hrm_test"
ActiveRecord::Migration.check_all_pending!
required_guards = %w[users_membership_insert_guard users_membership_update_guard]
guards = ActiveRecord::Base.connection.select_values("SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE()")
raise "Prepare hrm_test with bin/migrate-docker test; membership guards missing" unless (required_guards - guards).empty?
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
