module HrmRecruitment
  module Application
    module Requests
      class CandidateRequest
        WEB_FIELDS = [:full_name, :email, :position, :stage, :notes].freeze
        API_FIELDS = [:full_name, :email, :position, :stage, :notes].freeze
        def self.read(params, api: false)
          params.require(:candidate).permit(*(api ? API_FIELDS : WEB_FIELDS)).to_h.symbolize_keys
        end
      end
    end
  end
end
