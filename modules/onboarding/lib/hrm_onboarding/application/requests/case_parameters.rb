module HrmOnboarding
  module Application
    module Requests
      class CaseParameters
        def self.read(params)
          input = params.require(:onboarding_case)
          raise ActionController::ParameterMissing, :onboarding_case unless input.is_a?(ActionController::Parameters)
          input.permit(:employee_id, :start_date).to_h.symbolize_keys
        end
      end
    end
  end
end
