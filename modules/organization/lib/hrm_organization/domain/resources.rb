module HrmOrganization
  module Domain
    class Resources
      DEFINITIONS = {
        "cost_centers" => { model: "CostCenter", label: "Trung tâm chi phí", fields: { code: [ "Mã", :text ], name: [ "Tên", :text ], annual_budget: [ "Ngân sách năm", :money ], currency: [ "Tiền tệ", :currency ] } },
        "organization_units" => { model: "OrganizationUnit", label: "Đơn vị tổ chức", fields: { code: [ "Mã", :text ], name: [ "Tên", :text ], unit_type: [ "Loại đơn vị", :unit_type ], parent_id: [ "Đơn vị cha", :unit ], cost_center_id: [ "Trung tâm chi phí", :cost_center ], headcount_limit: [ "Giới hạn nhân sự", :integer ], effective_from: [ "Hiệu lực từ", :date ], effective_to: [ "Hiệu lực đến", :date ] } },
        "job_positions" => { model: "JobPosition", label: "Vị trí công việc", fields: { code: [ "Mã", :text ], title: [ "Chức danh", :text ], organization_unit_id: [ "Đơn vị tổ chức", :unit ], job_grade: [ "Ngạch", :text ], career_level: [ "Cấp nghề nghiệp (1–6)", :integer ], approved_headcount: [ "Định biên", :integer ], budgeted_cost: [ "Chi phí dự toán", :money ], is_critical: [ "Vị trí trọng yếu", :boolean ] } },
        "employee_assignments" => { model: "EmployeeAssignment", label: "Phân công nhân sự", fields: { employee_id: [ "Nhân viên", :employee ], organization_unit_id: [ "Đơn vị tổ chức", :unit ], job_position_id: [ "Vị trí", :position ], allocation_percent: [ "Phân bổ (%)", :money ], effective_from: [ "Hiệu lực từ", :date ], effective_to: [ "Hiệu lực đến", :date ] } }
      }.freeze
      def self.fetch(resource) = DEFINITIONS.fetch(resource.to_s) { raise ActiveRecord::RecordNotFound }
      def self.model(resource) = fetch(resource).fetch(:model).constantize
      def self.path(resource)
        fetch(resource)
        "/organization/#{resource.to_s.tr('_', '-')}"
      end
    end
  end
end
