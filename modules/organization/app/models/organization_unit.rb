class OrganizationUnit < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  KINDS = %w[company branch division department section team].freeze
  belongs_to :parent, class_name: "OrganizationUnit", optional: true
  belongs_to :cost_center, optional: true
  has_many :children, class_name: "OrganizationUnit", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :job_positions, dependent: :restrict_with_error
  has_many :employee_assignments, dependent: :restrict_with_error
  validates :code, presence: true, length: { maximum: 30 }, format: { with: /\A[A-Za-z0-9_-]+\z/ }, uniqueness: { scope: :company_id }
  validates :name, presence: true, length: { maximum: 255 }
  validates :unit_type, inclusion: { in: KINDS }
  validates :effective_from, presence: true
  validates :headcount_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate do
    same_company_as(:parent, :cost_center)
    errors.add(:parent_id, "không tồn tại") if parent_id.present? && parent.nil?
    errors.add(:cost_center_id, "không tồn tại") if cost_center_id.present? && cost_center.nil?
    errors.add(:effective_to, "phải từ ngày bắt đầu trở đi") if effective_from && effective_to && effective_to < effective_from
    if parent && KINDS.include?(unit_type) && KINDS.include?(parent.unit_type) && KINDS.index(unit_type) <= KINDS.index(parent.unit_type)
      errors.add(:unit_type, "đơn vị con phải thấp hơn cấp đơn vị cha")
    end
    cursor, seen = parent, []
    while cursor
      if (persisted? && cursor.id == id) || seen.include?(cursor.id)
        errors.add(:parent_id, "không được tạo vòng lặp")
        break
      end
      seen << cursor.id
      cursor = cursor.parent
    end
    if persisted? && KINDS.include?(unit_type) && children.where.not(unit_type: KINDS.drop(KINDS.index(unit_type) + 1)).exists?
      errors.add(:unit_type, "không phù hợp với cấp của đơn vị con hiện có")
    end
  end
end
