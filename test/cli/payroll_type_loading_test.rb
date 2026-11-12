require "test_helper"
require "open3"

class PayrollTypeLoadingTest < ActiveSupport::TestCase
  test "cold capture loads its result type before any reconciliation query or eager loading" do
    code = 'result = HrmPayroll::Infrastructure::Persistence::PayrollReconciliation.capture(run: PayRun.new(period: Date.new(2026, 11, 1))); puts result.fetch("payslip_count")'
    output, status = Open3.capture2e({ "RAILS_ENV" => "test" }, RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", code)
    assert status.success?, "Cold Payroll capture failed (output withheld)"
    assert_equal "0", output.strip
  end
end
