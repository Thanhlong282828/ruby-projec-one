require "test_helper"
class PayrollCsvTest < ActiveSupport::TestCase
  def service = HrmPayroll::Domain::Services::PayrollCsv
  def input(code: "NV001")
    { public_id: SecureRandom.uuid, period: Date.current.beginning_of_month, rows: [ { employee_code: code, gross_cents: 12345678, deductions_cents: 678, net_cents: 12345000 } ] }
  end
  test "CSV escapes formula triggers preserves Unicode and emits VND without scaling" do
    [ "=1+1", "+SUM(A1)", "-1+2", "@SUM(A1)", "  =1+1", "\tFORMULA", "\rFORMULA", "\nFORMULA", "\uFEFF=1" ].each do |code|
      data = input(code: code)
      result = service.build(**data)
      row = CSV.parse(result[:bytes].delete_prefix("\uFEFF"), headers: true).first
      assert_equal "'#{code}", row["employee_code"]
      assert_equal "12345678", row["gross_amount"]
      assert_equal "VND", row["currency"]
      assert_equal "0", row["amount_scale"]
      assert_equal result[:bytes], service.verify!(**result.except(:bytes).merge(bytes: result[:bytes], public_id: data[:public_id], period: data[:period]))
    end
    data = input(code: "NV,Nhân sự\"A")
    result = service.build(**data)
    assert_equal "NV,Nhân sự\"A", CSV.parse(result[:bytes].delete_prefix("\uFEFF"), headers: true).first["employee_code"]
  end
  test "binary valid UTF8 bytes are preserved and invalid UTF8 is rejected" do
    data = input(code: "Nhân sự".b)
    result = service.build(**data)
    assert_equal result[:bytes], service.verify!(**result.merge(bytes: result[:bytes].b, public_id: data[:public_id], period: data[:period]))
    assert_raises(service::InvalidSource) { service.build(**input(code: "bad\xFF".b)) }
    assert_raises(service::IntegrityError) { service.verify!(**result.merge(bytes: "bad\xFF".b, public_id: data[:public_id], period: data[:period])) }
  end
  test "invalid amounts row caps and NUL input rejected" do
    [ [], Array.new(2001, input[:rows].first) ].each do |rows|
      assert_raises(service::InvalidSource) { service.build(**input.merge(rows: rows)) }
    end
    [ "", "x" * 101, "bad\0code" ].each { |code| assert_raises(service::InvalidSource) { service.build(**input(code: code)) } }
    data = input
    data[:rows].first[:net_cents] = 0
    assert_raises(service::InvalidSource) { service.build(**data) }
  end
  test "checksum size uuid and period bind artifact identity" do
    data = input
    result = service.build(**data)
    args = result.merge(public_id: data[:public_id], period: data[:period])
    [ { checksum: "0" * 64 }, { byte_size: 1 }, { public_id: SecureRandom.uuid }, { period: Date.current + 2.months }, { employee_count: 999 } ].each do |changes|
      assert_raises(service::IntegrityError) { service.verify!(**args.merge(changes)) }
    end
  end
end
