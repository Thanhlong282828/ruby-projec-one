require "test_helper"
require "json"

class ErpQueryBudgetTest < ActiveSupport::TestCase
  def measure
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:cached] || payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|SET|SHOW)/i)
    end
    ActiveRecord::Base.uncached { yield }
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "employee listing reconciliation and snapshot CSV have bounded query growth" do
    results = {}
    [ 1, 20 ].each do |size|
      company = Company.create!(code: "BUDGET#{size}", name: "Disposable budget sample #{size}")
      admin = make_user(:admin, company: company)
      size.times { make_employee(make_user(:employee, company: company)) }
      run = Payroll::BuildRun.call(period: Date.new(2026, 11, 1), actor: admin)
      results[size] = {}
      results[size][:employees] = measure do
        records = HrmWorkforce::Application::Queries::ListEmployees.new.call(actor: admin)
        assert_equal size, records.size
        records.each { |record| assert record.department.name.present? }
      end
      results[size][:reconciliation] = measure do
        data = HrmPayroll::Application::Queries::ReconcilePayRun.new.call(actor: admin, run: run)
        assert_equal size, data.fetch(:current).fetch("payslip_count")
      end
      Payroll::FinalizeRun.call(run: run, actor: admin)
      results[size][:export] = measure do
        artifact = HrmPayroll::Application::Commands::CreateExport.new.call(actor: admin, pay_run_id: run.id)
        assert_equal size, artifact.employee_count
      end
    end
    puts "ERP_QUERY_BUDGET=#{JSON.generate(results)}"
    # Observed uncached SQL baseline: employees 9, reconciliation 20, CSV creation 49,
    # both at 1 and 20 employees. Small fixed margins allow setup differences, not N+1.
    { employees: 11, reconciliation: 22, export: 52 }.each do |operation, ceiling|
      assert_operator results[20][operation], :<=, results[1][operation] + 1, "#{operation} query growth"
      assert_operator results[20][operation], :<=, ceiling, "#{operation} fixed query budget"
    end
  end
end
