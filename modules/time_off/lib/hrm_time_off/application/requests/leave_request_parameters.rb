module HrmTimeOff
  module Application
    module Requests
      class LeaveRequestParameters
        WEB_FIELDS = [:employee_id, :starts_on, :ends_on, :reason].freeze
        API_FIELDS = [:employee_id, :starts_on, :ends_on, :reason].freeze
        def self.read(params, api: false)
          params.require(:leave_request).permit(*(api ? API_FIELDS : WEB_FIELDS)).to_h.symbolize_keys
        end
      end
    end
  end
end
