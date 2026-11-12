require "test_helper"
class ConcurrentStaffingTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  test "two database connections cannot consume the same approved vacancy" do
    company = Company.create!(code: "RACE_#{SecureRandom.hex(4).upcase}", name: "Concurrency test")
    admin = make_user(:admin, company: company)
    create = HrmOrganization::Application::Commands::CreateRecord.new
    unit = create.call(actor: admin, resource: "organization_units", attributes: { code: "ROOT", name: "Root", unit_type: "company", effective_from: Date.current })
    position = create.call(actor: admin, resource: "job_positions", attributes: { code: "ONE", title: "One vacancy", organization_unit_id: unit.id, approved_headcount: 1 })
    employees = Array.new(2) { make_employee(make_user(:employee, company: company)) }
    gate, results = Queue.new, Queue.new
    threads = employees.map do |employee|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            actor = User.find(admin.id)
            HrmOrganization::Application::Commands::CreateRecord.new.call(actor: actor, resource: "employee_assignments", attributes: { employee_id: employee.id, organization_unit_id: unit.id, job_position_id: position.id, effective_from: Date.current })
            results << :created
          rescue ActiveRecord::RecordInvalid
            results << :rejected
          rescue StandardError => error
            results << error
          ensure
            Current.reset
          end
        end
      end
    end
    2.times { gate << true }
    threads.each { |thread| assert thread.join(20), "Concurrent write did not finish" }
    outcomes = Array.new(2) { results.pop }
    assert_equal [ :created, :rejected ], outcomes.sort_by(&:to_s), outcomes.inspect
    assert_equal 1, EmployeeAssignment.where(company_id: company.id).count
  ensure
    Array(threads).each { |thread| thread.kill if thread.alive? }
    if company&.persisted?
      [ EmployeeAssignment, JobPosition, OrganizationUnit, CostCenter, AuditLog, OutboxEvent, Employee, Department ].each { |model| model.where(company_id: company.id).delete_all }
      ids = User.where(company_id: company.id).pluck(:id)
      UserPermission.where(user_id: ids).delete_all
      ApiToken.where(user_id: ids).delete_all
      User.where(company_id: company.id).delete_all
      RolePermission.where(company_role_id: CompanyRole.where(company_id: company.id).select(:id)).delete_all
      CompanyRole.where(company_id: company.id).delete_all
      company.reload.destroy!
    end
  end
end
