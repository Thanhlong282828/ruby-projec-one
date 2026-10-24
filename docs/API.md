# REST API v1

Base URL: http://localhost:3100/api/v1. JSON request/response, lỗi có `error` và tùy trường hợp `details`. Danh sách 25 bản ghi/trang qua `?page=2`.

1. `POST /session` body `{"email":"admin@hrm.local","password":"..."}` → 201 `{token,token_type,expires_in}`.
2. Các request tiếp theo: `Authorization: Bearer <token>`.
3. `DELETE /session` → 204, thu hồi token hiện tại.

| Resource | Endpoints | Quyền |
|---|---|---|
| employees | GET collection/detail | Staff: toàn bộ; employee/manager: hồ sơ bản thân |
| employees | POST, PATCH /:id | Admin/HR |
| employees | DELETE /:id | Admin; từ chối nếu có dữ liệu phụ thuộc |
| departments | GET, POST, PATCH /:id | Admin/HR |
| departments | DELETE /:id | Admin; phải không có nhân viên |
| leave_requests | GET collection/detail | Staff/manager: toàn bộ; employee: đơn bản thân |
| leave_requests | POST | Hồ sơ trong phạm vi được phép |
| leave_requests | PATCH /:id/approve, /:id/reject | Staff/manager, không tự duyệt |

Tạo nhân viên:
```json
{"employee":{"employee_code":"XV100","full_name":"Nguyễn An","email":"an@example.test","job_title":"Engineer","department_id":1,"hired_on":"2026-10-25","salary_cents":20000000}}
```

Tạo đơn:
```json
{"leave_request":{"employee_id":1,"starts_on":"2026-11-01","ends_on":"2026-11-02","reason":"Việc gia đình"}}
```

`salary_cents` dùng đơn vị VND nguyên (tên storage mang tính generic). Sửa nhân viên nên gửi `lock_version` từ GET gần nhất để phát hiện chỉnh sửa đồng thời (409). API nhân viên không cho liên kết user hoặc đọc dữ liệu ngân hàng/giấy tờ/lương. Liên kết tài khoản qua giao diện staff.

Mã lỗi: 400 thiếu tham số, 401 chưa xác thực/token hết hạn, 403 không đủ quyền, 404 không tồn tại/ngoài scope, 409 xung đột trạng thái, 422 validation, 429 giới hạn đăng nhập.

API hiện bao phủ employees/departments/leave requests. Chấm công, bảng lương, ứng viên và audit thực hiện qua giao diện web; chưa có endpoint API cho các module này.
