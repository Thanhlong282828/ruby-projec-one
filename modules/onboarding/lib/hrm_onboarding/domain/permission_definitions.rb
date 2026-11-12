module HrmOnboarding
  module Domain
    class PermissionDefinitions
      DEFINITIONS = { "onboarding.read" => "Xem tiếp nhận bản thân", "onboarding.read_all" => "Xem tiếp nhận company", "onboarding.create" => "Tạo hồ sơ tiếp nhận", "onboarding.manage" => "Xử lý tiếp nhận và checklist" }.freeze
      def self.for_role(role)
        case role
        when "admin", "hr" then DEFINITIONS.keys
        when "employee", "manager" then [ "onboarding.read" ]
        else []
        end
      end
    end
  end
end
