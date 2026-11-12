class EnforceAssignmentPositionUnit < ActiveRecord::Migration[8.1]
  def change
    add_index :job_positions, [ :company_id, :organization_unit_id, :id ], unique: true, name: "org_position_unit_identity"
    add_foreign_key :employee_assignments, :job_positions,
      column: [ :company_id, :organization_unit_id, :job_position_id ],
      primary_key: [ :company_id, :organization_unit_id, :id ], name: "org_assignment_position_unit"
  end
end
