module HrmPayroll
  module Application
    module Requests
      class PayRunRequest
        WEB_FIELDS = [:period].freeze
        API_FIELDS = [:period].freeze
        def self.read(params, api: false)
          params.require(:pay_run).permit(*(api ? API_FIELDS : WEB_FIELDS)).to_h.symbolize_keys
        end
      end
    end
  end
end
