module HrmWorkforce
  module Application
    module Requests
      class DepartmentRequest
        WEB_FIELDS = [:name, :code].freeze
        API_FIELDS = [:name, :code].freeze
        def self.read(params, api: false)
          params.require(:department).permit(*(api ? API_FIELDS : WEB_FIELDS)).to_h.symbolize_keys
        end
      end
    end
  end
end
