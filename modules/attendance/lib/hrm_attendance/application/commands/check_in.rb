module HrmAttendance
  module Application
    module Commands
      class CheckIn
        def initialize(service: Domain::Services::AttendanceCaptureService.new)
          @service = service
        end
        def call(actor:, at: Time.current) = @service.check_in(actor: actor, at: at)
      end
    end
  end
end
