module HrmAttendance
  module Domain
    class PermissionDefinitions
      DEFINITIONS = { "work_shifts.read" => "Xem ca làm việc", "work_shifts.create" => "Tạo ca làm việc", "work_shifts.update" => "Sửa ca làm việc", "work_shifts.delete" => "Xóa ca làm việc" }.freeze
      def self.for_role(role)
        case role
        when "admin" then DEFINITIONS.keys
        when "hr" then DEFINITIONS.keys - [ "work_shifts.delete" ]
        when "manager", "employee" then [ "work_shifts.read" ]
        else []
        end
      end
    end
  end
end
