ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
class ActiveSupport::TestCase
  self.use_transactional_tests = true
  setup do
    Current.reset
    Rails.cache.clear
    ActiveJob::Base.queue_adapter = :test
  end
  teardown { Current.reset }
  def make_user(role = :employee)
    User.create!(email: "#{SecureRandom.hex(6)}@example.test", password: "StrongPassword123!", role: role)
  end
  def make_employee(user = make_user, **overrides)
    department = Department.find_or_create_by!(code: "TEST") { |d| d.name = "Testing" }
    Employee.create!({ user: user, department: department, employee_code: SecureRandom.hex(4), full_name: "Test Person", email: user.email, job_title: "Engineer", hired_on: Date.current, salary_cents: 20000000 }.merge(overrides))
  end
end
