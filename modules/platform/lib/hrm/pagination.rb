module Hrm # Namespace của nghiệp vụ HRM
  module Pagination # Module chứa logic phân trang
    module_function # Cho phép gọi call trực tiếp trên module | Nhờ có: module_function Bạn có thể gọi: Hrm::Pagination.call(Employee.all, 2) | Mà không cần tạo đối tượng: pagination = Pagination.new | Trong Ruby, Module không được khởi tạo bằng .new như Class.
    def call(scope, page) # Nhận truy vấn và số trang
      scope.limit(25).offset(([ page.to_i, 1 ].max - 1) * 25) # scope.limit(25)	Mỗi trang tối đa 25 bản ghi  |  .offset(...)	Bỏ qua số bản ghi của các trang trước
    end
  end
end
# Đoạn code này đang xây dựng một Pagination Helper (phân trang) trong Ruby on Rails, thuộc namespace Hrm.
# Nó tương đương với việc bạn sử dụng LIMIT và OFFSET trong SQL hoặc paginate() trong Laravel.

# 1. Giải thích từng dòng
#   Thành phần                     	Ý nghĩa
# module Hrm	            Namespace của nghiệp vụ HRM
# module Pagination       Module chứa logic phân trang
# module_function       	Cho phép gọi call trực tiếp trên module
# def call(scope, page) 	Nhận truy vấn và số trang
# scope.limit(25)	        Mỗi trang tối đa 25 bản ghi
# .offset(...)	          Bỏ qua số bản ghi của các trang trước

# 2.Giải thích công thức OFFSET
#       ([page.to_i, 1].max - 1) * 25
# Tách ra:
#        page.to_i
# > Chuyển page thành số nguyên.
#        [page.to_i, 1].max
# > Lấy số lớn hơn giữa page và 1, đảm bảo trang tối thiểu là trang 1.
#        (page - 1) * 25
# > Tính số bản ghi cần bỏ qua.

# 3. Mô phỏng phân trang
# Chọn trang                         < 2 >
#   LIMIT        OFFSET        Bản ghi
#   25            25            26–50
# > SQL tương đương:     SELECT * FROM employees ORDER BY id LIMIT 25 OFFSET 25;
# > Minh họa với 125 bản ghi, sắp xếp theo ID. Thử chuyển trang để xem OFFSET thay đổi.

# 4. So sánh Ruby và Laravel
# Ruby on Rails:
#       employees = Hrm::Pagination.call(
#         Employee.order(:id),
#         params[:page]
#       )
# Laravel:
#       $employees = Employee::orderBy('id')
#           ->paginate(25);

# > Laravel paginate(25) cung cấp thêm tổng số bản ghi, tổng số trang, trang hiện tại và dữ liệu phục vụ hiển thị liên kết phân trang.
# - Trong khi đó, Hrm::Pagination.call() hiện tại chỉ giới hạn bản ghi bằng LIMIT/OFFSET, chưa tính tổng số trang.
# > Nếu muốn viết tương đương trực tiếp hơn trong Laravel:
#       $page = max((int) request('page', 1), 1);
#       $employees = Employee::orderBy('id')
#           ->limit(25)
#           ->offset(($page - 1) * 25)
#           ->get();

# 5. Hai lưu ý quan trọng
# - Cần order trước khi phân trang: Nếu không có thứ tự ổn định, dữ liệu giữa các trang có thể bị trùng hoặc thiếu khi truy vấn.
# - page.to_i không kiểm tra dữ liệu hợp lệ: Ví dụ "abc".to_i sẽ thành 0, sau đó được đưa về trang 1. Ngoài ra, page quá lớn có thể tạo OFFSET rất cao.

# Trang 4 sẽ lấy bản ghi từ vị trí 76 đến 100, tổng cộng 25 bản ghi.

# Công thức:
#     OFFSET = (page - 1) \times LIMIT
# Thay số:
#     OFFSET = (4 - 1) \times 25 = 75
# SQL tương ứng:
#     SELECT *
#     FROM employees
#     ORDER BY id
#     LIMIT 25 OFFSET 75;


#       - LIMIT 25: Lấy tối đa 25 bản ghi.
#       - OFFSET 75: Bỏ qua 75 bản ghi đầu tiên.
#       - Kết quả: Lấy bản ghi ở vị trí 76–100 trong thứ tự truy vấn.
# Trang       	OFFSET	      Vị trí bản ghi
# 1             	0 	            1–25
# 2             	25	            26–50
# 3             	50	            51–75
# 4             	75	            76–100

# Lưu ý: Vị trí bản ghi không nhất thiết bằng id trong database, vì ID có thể bị thiếu do xóa dữ liệu.
