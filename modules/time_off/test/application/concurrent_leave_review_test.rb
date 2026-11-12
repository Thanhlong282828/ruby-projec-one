require "test_helper"
require "timeout"

class ConcurrentLeaveReviewTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "cached balance cannot let two reviewers approve beyond one remaining day" do
    company = Company.create!(code: "LEAVERACE#{SecureRandom.hex(4).upcase}", name: "Leave review race")
    employee = make_employee(make_user(:employee, company: company), annual_leave_days: 1)
    reviewers = Array.new(2) { make_user(:hr, company: company) }
    requests = [ 3, 5 ].map { |day| employee.leave_requests.create!(starts_on: Date.new(2026, 11, day), ends_on: Date.new(2026, 11, day), reason: "Sample leave") }
    ready, gate, results = Queue.new, Queue.new, Queue.new
    threads = []
    employee.with_lock do
      threads = requests.zip(reviewers).map do |request, reviewer|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ActiveRecord::Base.cache do
              HrmTimeOff::Infrastructure::Persistence::ActiveRecordReadRepository.new.used_days(employee: employee, year: 2026)
              ready << true
              gate.pop
              begin
                HrmTimeOff::Application::Commands::ReviewLeave.new.call(request: request, reviewer: reviewer, decision: "approved")
                results << :approved
              rescue StandardError => error
                results << error
              ensure
                Current.reset
              end
            end
          end
        end
      end
      Timeout.timeout(10) { 2.times { ready.pop } }
      2.times { gate << true }
    end
    threads.each { |thread| assert thread.join(20), "Leave lock timed out" }
    outcomes = Array.new(2) { results.pop }
    assert_equal 1, outcomes.count(:approved)
    assert_equal(1, outcomes.count { |value| value.is_a?(HrmTimeOff::Domain::Services::LeaveReviewRules::InvalidTransition) })
    assert_equal 1, employee.leave_requests.approved.count
    assert_equal 1, employee.leave_requests.pending.count
    assert_equal 1, OutboxEvent.where(company_id: company.id, event_type: "leave_request.reviewed").count
  ensure
    Array(threads).each { |thread| thread.kill if thread.alive? }
    if company&.persisted?
      [ LeaveRequest, Employee, Department, AuditLog, OutboxEvent ].each { |model| model.where(company_id: company.id).delete_all }
      ids = User.where(company_id: company.id).pluck(:id)
      [ UserPermission, LoginSession, ApiToken ].each { |model| model.where(user_id: ids).delete_all }
      User.where(id: ids).delete_all
      RolePermission.where(company_role_id: CompanyRole.where(company_id: company.id).select(:id)).delete_all
      CompanyRole.where(company_id: company.id).delete_all
      company.reload.destroy!
    end
  end
  test "approval in an older caller transaction reads the latest committed used balance" do
    company = Company.create!(code: "LEAVESNAPSHOT#{SecureRandom.hex(3).upcase}", name: "Leave snapshot race")
    employee = make_employee(make_user(:employee, company: company), annual_leave_days: 1)
    reviewer = make_user(:hr, company: company)
    first, second = [ 8, 10 ].map { |day| employee.leave_requests.create!(starts_on: Date.new(2026, 11, day), ends_on: Date.new(2026, 11, day), reason: "Sample leave") }
    ready, gate, result = Queue.new, Queue.new, Queue.new
    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          ActiveRecord::Base.cache do
            ActiveRecord::Base.transaction do
              HrmTimeOff::Infrastructure::Persistence::ActiveRecordReadRepository.new.used_days(employee: employee, year: 2026)
              ready << true
              gate.pop
              HrmTimeOff::Application::Commands::ReviewLeave.new.call(request: second, reviewer: reviewer, decision: "approved")
            end
          end
          result << :approved
        rescue StandardError => error
          result << error
        ensure
          Current.reset
        end
      end
    end
    Timeout.timeout(10) { ready.pop }
    HrmTimeOff::Application::Commands::ReviewLeave.new.call(request: first, reviewer: reviewer, decision: "approved")
    gate << true
    assert worker.join(20), "Snapshot review lock timed out"
    assert_kind_of HrmTimeOff::Domain::Services::LeaveReviewRules::InvalidTransition, result.pop
    assert_equal 1, employee.leave_requests.approved.count
    assert second.reload.pending?
  ensure
    worker.kill if worker&.alive?
    if company&.persisted?
      [ LeaveRequest, Employee, Department, AuditLog, OutboxEvent ].each { |model| model.where(company_id: company.id).delete_all }
      ids = User.where(company_id: company.id).pluck(:id)
      [ UserPermission, LoginSession, ApiToken ].each { |model| model.where(user_id: ids).delete_all }
      User.where(id: ids).delete_all
      RolePermission.where(company_role_id: CompanyRole.where(company_id: company.id).select(:id)).delete_all
      CompanyRole.where(company_id: company.id).delete_all
      company.reload.destroy!
    end
  end
end
