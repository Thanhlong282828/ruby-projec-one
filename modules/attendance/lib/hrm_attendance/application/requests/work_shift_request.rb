module HrmAttendance
  module Application
    module Requests
      class WorkShiftRequest
        FIELDS = [ :code, :name, :start_time, :end_time, :unpaid_break_minutes, :grace_in_minutes,
          :grace_out_minutes, :overtime_threshold_minutes, :active, :lock_version ].freeze
        def self.read(params) = params.require(:work_shift).permit(*FIELDS).to_h.symbolize_keys
      end
    end
  end
end
