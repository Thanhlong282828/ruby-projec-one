class ApplicationRecord < ActiveRecord::Base # ApplicationRecord: Lớp Model cơ sở của ứng dụng. | <: Kế thừa (Inheritance) trong Ruby. | ActiveRecord::Base: Lớp ORM của Rails, cung cấp các chức năng truy vấn và thao tác database.
  primary_abstract_class # Nó đánh dấu ApplicationRecord là lớp abstract chính của hệ thống Active Record.
end
# Đoạn code này trong Ruby on Rails là ApplicationRecord,
# lớp Model cha dùng chung cho các Model sử dụng Active Record (ORM).

# Nó tương tự việc bạn tạo một BaseModel kế thừa Eloquent Model trong Laravel.




# Ví dụ:
# class Employee < ApplicationRecord
# end

# Model Employee sẽ kế thừa các khả năng Active Record như:
# Employee.all
# Employee.find(1)
# Employee.where(status: "active")
# Employee.create(name: "Thanh")


# primary_abstract_class

# Đây là điểm quan trọng nhất.

# Nó đánh dấu ApplicationRecord là lớp abstract chính của hệ thống Active Record.

#    Ý nghĩa:
#    - ApplicationRecord đóng vai trò lớp cha, không đại diện cho một bảng dữ liệu nghiệp vụ riêng.
#    - Rails không tự suy ra bảng application_records để sử dụng cho lớp abstract này.
#    - Các Model kế thừa vẫn được ánh xạ đến bảng tương ứng.
#    - Nó cũng xác lập ranh giới kế thừa chính cho một số cơ chế cấu hình Active Record, chẳng hạn connection specification.

#    Ví dụ:
#    class ApplicationRecord < ActiveRecord::Base
#      primary_abstract_class
#    end
#    class Employee < ApplicationRecord
#    end
#    class Company < ApplicationRecord
#    end
#
#
#    Rails sẽ ánh xạ:
#    Model	                  Database Table
#    ApplicationRecord    	Không có bảng riêng
#    Employee	                employees
#    Company	                companies
#
#    2. Luồng kế thừa Model
#    ActiveRecord::Base
#    ORM Framework của Rails
#             v
#    ApplicationRecord
#    primary_abstract_class
#       v              v
#    Employee       Company
#    employees     companies



#     Ruby on Rails	                          Laravel
#    ActiveRecord::Base	                Illuminate\Database\Eloquent\Model
#    ApplicationRecord	                BaseModel tự định nghĩa
#    primary_abstract_class            	abstract class (gần tương đương về mục đích)
#    Employee < ApplicationRecord     	Employee extends BaseModel
#    Employee.where(...)              	Employee::where(...)
#    Employee.find(1)                 	Employee::find(1)


#         1. So sánh hai cách
#                   Cách 1: Kế thừa trực tiếp                                 Cách 2: Qua ApplicationRecord
#                       ActiveRecord::Base                                           ActiveRecord::Base
#                           v                                                                v
#                         Employee                                                  ApplicationRecord
#  Hoạt động, nhưng không có lớp cấu hình chung riêng của ứng dụng.                         v
#                                                                                       Employee
#                                                                     Có lớp trung gian để quản lý cấu hình và hành vi chung.

# Tại sao không gọi trực tiếp trên ActiveRecord::Base?
# Vì ActiveRecord::Base là lớp gốc của framework và đã đóng vai trò nền tảng ORM.
# Gọi primary_abstract_class trực tiếp trên lớp framework không mang lại lợi ích tạo một ranh giới riêng cho các Model của ứng dụng.
#  Nó còn có thể ảnh hưởng đến cấu hình kế thừa và connection của những Model khác.

# ApplicationRecord tạo ra ranh giới đó.



# Câu hỏi : primary_abstract_class có phải là thứ cung cấp khả năng find, where, create cho Model không ?
# Không. primary_abstract_class không cung cấp các phương thức find, where, create.
#
# Các phương thức đó đến từ ActiveRecord::Base, tức ORM của Ruby on Rails.
#
# Ví dụ:
#     class ApplicationRecord < ActiveRecord::Base
#       primary_abstract_class
#     end
#
#     class Employee < ApplicationRecord
#     end
#
# Luồng kế thừa:
#     ActiveRecord::Base
#         │
#         │ Cung cấp find, where, create, update, destroy...
#         ▼
#     ApplicationRecord
#         │
#         │ primary_abstract_class
#         │ Đánh dấu lớp cha abstract chính
#         ▼
#     Employee
#         │
#         ▼
#     Employee.find(1)
#     Employee.where(status: "active")
#     Employee.create(name: "Thanh")
