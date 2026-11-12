module HrmOrganization
  module Domain
    class PermissionDefinitions
      NAMES = { "cost_centers" => "trung tâm chi phí", "organization_units" => "đơn vị tổ chức", "job_positions" => "vị trí", "employee_assignments" => "phân công" }.freeze
      ACTIONS = { "read" => "Xem", "create" => "Tạo", "update" => "Sửa", "delete" => "Xóa", "export" => "Xuất" }.freeze
      DEFINITIONS = NAMES.flat_map { |resource, name| ACTIONS.map { |action, label| [ "#{resource}.#{action}", "#{label} #{name}" ] } }.to_h.freeze
      ADMIN = DEFINITIONS.keys.freeze
      HR = ADMIN.reject { |key| key.end_with?(".delete") }.freeze
      MANAGER = ADMIN.select { |key| key.end_with?(".read") }.freeze
      DEFAULTS = { "admin" => ADMIN, "hr" => HR, "manager" => MANAGER }.freeze
      def self.for_role(role) = DEFAULTS.fetch(role, [])
    end
  end
end
