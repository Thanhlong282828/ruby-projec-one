class PayrollExport < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :pay_run
  belongs_to :created_by, class_name: "User"
  has_many :payroll_export_accesses, dependent: :restrict_with_error
  encrypts :artifact
  METADATA_COLUMNS = %i[id company_id public_id pay_run_id created_by_id period format version employee_count byte_size checksum created_at].freeze
  validates :public_id, format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/ }, uniqueness: true
  validates :format, inclusion: { in: [ "payroll_csv_v1" ] }
  validates :version, inclusion: { in: [ 1 ] }
  validates :employee_count, numericality: { only_integer: true, in: 1..2000 }
  validates :byte_size, numericality: { only_integer: true, in: 1..1_048_576 }
  validates :checksum, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :period, :artifact, presence: true
  validates :pay_run_id, uniqueness: { scope: :company_id }
  validate { same_company_as(:pay_run, :created_by) }
  def readonly? = persisted?
  def filename = "payroll-#{period.strftime('%Y-%m')}-#{public_id}.csv"
  def public_attributes
    (METADATA_COLUMNS - [ :company_id ]).to_h { |key| [ key.to_s, public_send(key) ] }
  end
  def serializable_hash(_options = nil) = public_attributes
end
