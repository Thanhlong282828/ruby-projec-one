module CompanyOwned # module CompanyOwned: Tạo module dùng chung cho nhiều Model.
  extend ActiveSupport::Concern # extend ActiveSupport::Concern: Hỗ trợ tổ chức logic khi module được include vào Mod   |   Ví dụ:  class Employee < ApplicationRecord include CompanyOwned end  |  Model Employee sẽ nhận các association, scope, validation và phương thức của CompanyOwned.
  included do # included do khai báo những thành phần được áp dụng vào Model khi include module.
    belongs_to :company # Thiết lập quan hệ nhiều-một:   |  Tương đương Laravel:  public function company(){return $this->belongsTo(Company::class);}
    scope :for_company, ->(company_id) { where(company_id: company_id) } # Đây là Local Scope, giúp tái sử dụng điều kiện truy vấn.  |  Ví dụ: Employee.for_company(10)  Tương đương SQL: SELECT * FROM employees WHERE company_id = 10;  |  Laravel:  public function scopeForCompany($query, int $companyId){ return $query->where('company_id', $companyId); }  Gọi:  Employee::forCompany(10)->get(); |  Lưu ý: Scope này không tự động được áp dụng cho mọi truy vấn. Nếu gọi Employee.all, bạn vẫn có thể truy vấn toàn bộ nhân viên nếu không có lớp giới hạn khác.
   # 2. Validation ngăn chuyển công ty
    validate do
      errors.add(:company_id, "cannot be moved to another company") if persisted? && will_save_change_to_company_id? # persisted? :  Bản ghi đã tồn tại trong database  |  will_save_change_to_company_id? : company_id có thay đổi và đang chờ lưu
    end
  end
  # 3. same_company_as(*links) là gì?
  private
  def same_company_as(*links) # *links: Nhận nhiều tên association.
    links.each do |link| # links.each: Lặp qua từng association.
      target = public_send(link) # public_send(link): Gọi phương thức association theo tên.
      errors.add(link, "must belong to the same company") if target && target.company_id != company_id # - errors.add: Thêm lỗi validation nếu khác công ty. |  target.company_id != company_id: So sánh công ty của bản ghi liên quan với công ty hiện tại.
    end
  end
end
# Đoạn code này trong Ruby on Rails là một ActiveSupport::Concern dùng để bảo vệ dữ liệu Multi-Tenant (đa công ty).

# Nó giúp các Model thuộc một công ty không bị chuyển sang công ty khác và hỗ trợ kiểm tra các bản ghi liên quan có thuộc cùng công ty hay không.

# Đây là một phần quan trọng trong bảo mật dữ liệu HRM, ERP.


#trait CompanyOwned
#{
#    public function company()
#    {
#        return $this->belongsTo(Company::class);
#    }
#
#    public function scopeForCompany($query, int $companyId)
#    {
#        return $query->where('company_id', $companyId);
#    }
#
#    protected static function bootCompanyOwned(): void
#    {
#        static::updating(function ($model) {
#            if ($model->isDirty('company_id')) {
#                throw new LogicException(
#                    'Cannot move record to another company'
#                );
#            }
#        });
#    }
#}
