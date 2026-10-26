module HrmWorkforce
  module Application
    module Requests
      class EmployeeRequest
        WEB_FIELDS = [:department_id, :user_id, :employee_code, :full_name, :email, :job_title, :hired_on, :status, :salary_cents, :annual_leave_days, :bank_account, :national_id, :lock_version].freeze
        API_FIELDS = [:employee_code, :full_name, :email, :job_title, :hired_on, :status, :department_id, :salary_cents, :annual_leave_days, :lock_version].freeze
        def self.read(params, api: false)
          params.require(:employee).permit(*(api ? API_FIELDS : WEB_FIELDS)).to_h.symbolize_keys
        end
      end
    end
  end
end
