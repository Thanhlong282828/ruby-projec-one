class RolePermission < ApplicationRecord
  belongs_to :company_role
  belongs_to :permission
  validates :permission_id, uniqueness: { scope: :company_role_id }
end
