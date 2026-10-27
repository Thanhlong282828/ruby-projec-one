require "test_helper"
class AuditDomainTest < ActiveSupport::TestCase
  test "audit and outbox roll back with employee transaction" do
    before_counts = [Employee.count, AuditLog.count, OutboxEvent.count]
    Employee.transaction do
      make_employee
      raise ActiveRecord::Rollback
    end
    assert_equal before_counts, [Employee.count, AuditLog.count, OutboxEvent.count]
  end
  test "observer attributes changes without storing sensitive values" do
    actor = make_user(:admin)
    Current.user = actor
    employee = make_employee(bank_account: "secret-value")
    log = AuditLog.find_by!(record_type: "Employee", record_id: employee.id)
    assert_equal actor.id, log.actor_id
    assert_not_includes log.metadata.to_json, "secret-value"
    assert_not_includes log.metadata["changed_fields"], "bank_account"
  end
end
