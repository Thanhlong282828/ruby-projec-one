require "test_helper"
class ConcurrentShiftAssignmentsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  test "two connections cannot assign overlapping shifts to the same employee" do
    company=Company.create!(code: "SCHEDULE_#{SecureRandom.hex(4).upcase}", name: "Schedule race test")
    admin=make_user(:admin, company: company)
    employee=make_employee(make_user(:employee, company: company))
    shift=HrmAttendance::Application::Commands::CreateWorkShift.new.call(actor: admin,
      attributes: { code: "DAY", name: "Day", start_time: "08:00", end_time: "17:00" })
    gate, outcomes=Queue.new, Queue.new
    threads=Array.new(2) do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            HrmAttendance::Application::Commands::CreateShiftAssignment.new.call(actor: User.find(admin.id),
              attributes: { employee_id: employee.id, work_shift_id: shift.id, effective_from: Date.current+i, effective_to: Date.current+5 })
            outcomes << :created
          rescue ActiveRecord::RecordInvalid
            outcomes << :rejected
          rescue StandardError=>error
            outcomes << error
          ensure
            Current.reset
          end
        end
      end
    end
    2.times { gate << true }
    threads.each { |thread| assert thread.join(20), "Assignment lock timed out" }
    result=Array.new(2) { outcomes.pop }
    assert_equal [ :created, :rejected ], result.sort_by(&:to_s), result.inspect
    assert_equal 1, EmployeeShiftAssignment.where(company_id: company.id).count
  ensure
    Array(threads).each { |thread| thread.kill if thread.alive? }
    if company&.persisted?
      [ EmployeeShiftAssignment, WorkShift, AuditLog, OutboxEvent, Employee, Department ].each { |model| model.where(company_id: company.id).delete_all }
      ids=User.where(company_id: company.id).pluck(:id)
      UserPermission.where(user_id: ids).delete_all
      ApiToken.where(user_id: ids).delete_all
      LoginSession.where(user_id: ids).delete_all
      User.where(company_id: company.id).delete_all
      RolePermission.where(company_role_id: CompanyRole.where(company_id: company.id).select(:id)).delete_all
      CompanyRole.where(company_id: company.id).delete_all
      company.reload.destroy!
    end
  end
end
