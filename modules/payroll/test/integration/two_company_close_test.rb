require "test_helper"

class TwoCompanyPayrollCloseTest < ActionDispatch::IntegrationTest
  def login_as(actor)
    post "/session", params: { email: actor.email, password: "StrongPassword123!" }
    assert_response :redirect
  end

  test "two companies reconcile attendance leave and close independent salary snapshots with scoped access" do
    company_a = Company.create!(code: "FLOWA#{SecureRandom.hex(3).upcase}", name: "Sample company A")
    company_b = Company.create!(code: "FLOWB#{SecureRandom.hex(3).upcase}", name: "Sample company B")
    fixtures = [ [ company_a, 20_000_000, 1 ], [ company_b, 30_000_000, 2 ] ].map do |company, salary, days|
      admin = make_user(:admin, company: company)
      employee = make_employee(make_user(:employee, company: company), employee_code: "EMP-ORIGINAL", full_name: "Original #{company.code}", salary_cents: salary, hired_on: Date.new(2026, 11, 1))
      attendance = HrmAttendance::Application::Commands::CheckIn.new.call(actor: employee.user, at: Time.zone.local(2026, 11, 2, 8))
      HrmAttendance::Application::Commands::CheckOut.new.call(actor: employee.user, id: attendance.id, at: Time.zone.local(2026, 11, 2, 17))
      leave = HrmTimeOff::Application::Commands::SubmitLeave.new.call(actor: employee.user, employee_id: employee.id, attributes: { starts_on: Date.new(2026, 11, 4), ends_on: Date.new(2026, 11, 3 + days), reason: "Sample leave" })
      login_as(admin)
      post "/pay_runs", params: { pay_run: { period: "2026-11-01" } }
      assert_response :redirect
      run = PayRun.find_by!(company_id: company.id, period: Date.new(2026, 11, 1))
      pending = HrmPayroll::Application::Queries::ReconcilePayRun.new.call(actor: admin, run: run)
      assert_equal 1, pending[:current].fetch("pending_leave_count")
      HrmTimeOff::Application::Commands::ReviewLeave.new.call(request: leave, reviewer: admin, decision: "approved")
      employee.update!(employee_code: "AFTER-#{company.id}", full_name: "Changed #{company.code}", salary_cents: salary + 10_000_000)
      patch "/pay_runs/#{run.id}/finalize"
      assert_response :redirect
      assert run.reload.finalized?
      snapshot = run.reconciliation_snapshot
      assert_equal 1, snapshot.fetch("attendance_count")
      assert_equal 0, snapshot.fetch("open_attendance_count")
      assert_equal 0, snapshot.fetch("pending_leave_count")
      assert_equal days, snapshot.fetch("approved_leave_days")
      assert_equal salary, snapshot.fetch("net_total")
      assert_equal salary, run.payslips.first.net_cents
      get "/pay_runs/#{run.id}"
      assert_response :success
      assert_includes response.body, "Original #{company.code}"
      assert_not_includes response.body, "Changed #{company.code}"
      assert_includes response.body, "Đối soát đã lưu tại thời điểm chốt"
      headers = { "Authorization" => "Bearer #{ApiToken.issue!(admin)}" }
      post "/api/v1/payroll/exports", params: { pay_run_id: run.id }, headers: headers, as: :json
      assert_response :created
      export_id = response.parsed_body.fetch("id")
      get "/api/v1/payroll/exports/#{export_id}/download", headers: headers
      assert_response :success
      assert_includes response.body, "EMP-ORIGINAL"
      assert_includes response.body, salary.to_s
      assert_not_includes response.body, "AFTER-"
      assert_equal snapshot, HrmPayroll::Application::Queries::ReconcilePayRun.new.call(actor: admin, run: run)[:captured]
      { admin: admin, employee: employee, run: run, export_id: export_id }
    end
    first, second = fixtures
    login_as(first[:admin])
    get "/pay_runs/#{second[:run].id}"
    assert_response :not_found
    get "/api/v1/payroll/exports/#{second[:export_id]}/download", headers: { "Authorization" => "Bearer #{ApiToken.issue!(first[:admin])}" }
    assert_response :not_found
    employee = first[:employee].user
    login_as(employee)
    get "/pay_runs/#{first[:run].id}"
    assert_response :not_found
    grant = employee.user_permissions.create!(permission: Permission.find_by!(key: "payroll.read"), granted: true)
    get "/pay_runs/#{first[:run].id}"
    assert_response :success
    assert_includes response.body, "Cần quyền xem chấm công và nghỉ phép"
    assert_not_includes response.body, "Đối soát đã lưu tại thời điểm chốt"
    grant.update!(granted: false)
    get "/pay_runs/#{first[:run].id}"
    assert_response :not_found
  end
end
