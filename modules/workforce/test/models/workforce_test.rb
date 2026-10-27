require "test_helper"
class WorkforceDomainTest < ActiveSupport::TestCase
  test "employee validates uniqueness and nonnegative salary" do
    employee = make_employee
    duplicate = Employee.new(employee.attributes.except("id", "created_at", "updated_at"))
    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :employee_code
    employee.salary_cents = -1
    assert_not employee.valid?
  end
  test "sensitive fields are encrypted at rest" do
    employee = make_employee(bank_account: "1234567890", national_id: "SECRET-ID")
    raw = Employee.connection.select_one("SELECT bank_account, national_id FROM employees WHERE id = #{employee.id}")
    assert_not_equal "1234567890", raw["bank_account"]
    assert_not_equal "SECRET-ID", raw["national_id"]
    assert_equal "1234567890", employee.reload.bank_account
  end
  test "department with employees cannot be removed" do
    employee = make_employee
    assert_not employee.department.destroy
  end
end
