module ApplicationHelper
end
# Hiện tại module này đang trống, chưa có phương thức nào được định nghĩa.
# 1. ApplicationHelper dùng để làm gì?
# ApplicationHelper dùng để chứa các phương thức hỗ trợ View (giao diện), giúp tránh viết logic hiển thị lặp lại trong các file .html.erb.

# Ví dụ trong hệ thống HRM, bạn muốn hiển thị trạng thái nhân viên bằng tiếng Việt.
# module ApplicationHelper
# def employee_status(status)
# case status
# when "active"
# "Đang làm việc"
# when "inactive"
# "Ngừng hoạt động"
# else
# "Không xác định"
# end
# end
# end


# Sau đó gọi trực tiếp trong ERB:
# <td><%= employee_status(employee.status) %></td>


# Nếu employee.status = "active", giao diện sẽ hiển thị
# Đang làm việc

# 2. So sánh với Laravel
# Ruby on Rails	                    Laravel
# ApplicationHelper             	Helper PHP hoặc View Component
# module	                        Tập hợp các phương thức dùng chung
# def employee_status           	function employeeStatus()
# .html.erb	                       .blade.php
# <%= employee_status(...) %>	    {{ employeeStatus(...) }}
