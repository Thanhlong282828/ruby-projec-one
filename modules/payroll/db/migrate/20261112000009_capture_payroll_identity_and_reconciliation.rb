class CapturePayrollIdentityAndReconciliation < ActiveRecord::Migration[8.1]
  def up
    # Existing rows remain unknown rather than inventing historical identity.
    add_column :payslips, :employee_code_snapshot, :string unless column_exists?(:payslips, :employee_code_snapshot)
    add_column :payslips, :employee_name_snapshot, :string unless column_exists?(:payslips, :employee_name_snapshot)
    add_column :pay_runs, :reconciliation_snapshot, :json unless column_exists?(:pay_runs, :reconciliation_snapshot)
  end
  def down
    remove_column :pay_runs, :reconciliation_snapshot if column_exists?(:pay_runs, :reconciliation_snapshot)
    remove_column :payslips, :employee_name_snapshot if column_exists?(:payslips, :employee_name_snapshot)
    remove_column :payslips, :employee_code_snapshot if column_exists?(:payslips, :employee_code_snapshot)
  end
end
