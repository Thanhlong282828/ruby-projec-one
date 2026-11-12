module HrmAttendance
  module Domain
    class SchedulePermissionDefinitions
      DEFINITIONS = { "shift_assignments.read"=>"Xem phân ca của mình", "shift_assignments.read_all"=>"Xem phân ca company", "shift_assignments.create"=>"Tạo phân ca", "shift_assignments.update"=>"Kết thúc phân ca", "shift_assignments.delete"=>"Xóa phân ca tương lai" }.freeze
      def self.for_role(role)
        case role
        when "admin" then DEFINITIONS.keys
        when "hr" then DEFINITIONS.keys - [ "shift_assignments.delete" ]
        when "manager" then [ "shift_assignments.read", "shift_assignments.read_all" ]
        when "employee" then [ "shift_assignments.read" ]
        else []
        end
      end
    end
  end
end
