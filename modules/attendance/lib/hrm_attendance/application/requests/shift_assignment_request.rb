module HrmAttendance
  module Application
    module Requests
      class ShiftAssignmentRequest
        FIELDS = [ :employee_id, :work_shift_id, :effective_from, :effective_to, :lock_version ].freeze
        def self.read(params) = params.require(:shift_assignment).permit(*FIELDS).to_h.symbolize_keys
      end
    end
  end
end
