# Menu ERP và luồng Dashboard → nguồn

Phạm vi: source Rails 12 Engines. LaravelDji chỉ tham chiếu cách gom miền, không chứng nhận ngang tính năng. Đã đọc tài liệu read-only `Desktop/laraveldji/admin/docs/erp-navigation-domain-map.md` và `erp-sidebar-feature-audit.md`: giữ nhóm có con được phép, không menu trống. Bản kiểm chứng cụ thể nằm trong VERIFICATION.md.

## Registry menu hoạt động

Sidebar và bảng Không gian nghiệp vụ đều dùng `ErpNavigationHelper#erp_navigation_groups`. Lọc server qua quyền MySQL của current_user; nhóm không có con được phép bị ẩn. Mọi điểm đến vẫn có Query/Policy; menu không thay authorization. Company lấy từ profile/session đã xác thực, không đọc company_id từ bộ lọc. SystemGrant độc lập với quyền company.

| Nhóm / mục | Route web | Query của module sở hữu | Quyền đọc |
|---|---|---|---|
| Nhân sự / Hồ sơ nhân viên | /employees | Workforce::ListEmployees | employees.read hoặc employees.read_all |
| Cơ cấu / Phòng ban | /departments | Workforce::ListDepartments | departments.read |
| Cơ cấu / Chi nhánh | /organization/branches | Organization::Branches | organization_units.read |
| Cơ cấu / Cây tổ chức | /organization/tree | Organization::Structure | organization_units.read |
| Cơ cấu / Đơn vị | /organization/organization-units | Organization::Workspace | organization_units.read |
| Cơ cấu / Trung tâm chi phí | /organization/cost-centers | Organization::Workspace | cost_centers.read |
| Cơ cấu / Vị trí | /organization/job-positions | Organization::Workspace | job_positions.read |
| Cơ cấu / Phân công | /organization/employee-assignments | Organization::Workspace | employee_assignments.read |
| Cơ cấu / Định biên | /organization/headcount | Organization::Structure | đủ organization_units.read + job_positions.read + employee_assignments.read |
| Chấm công / Nhật ký | /attendances | Attendance::ListAttendances | attendance.read hoặc attendance.read_all |
| Chấm công / Báo cáo | /attendances/report | Attendance::PeriodReport | attendance.read hoặc attendance.read_all |
| Chấm công / Ca làm việc | /work_shifts | Attendance::WorkShiftWorkspace | work_shifts.read |
| Chấm công / Phân ca | /shift_assignments | Attendance::ShiftAssignmentWorkspace | shift_assignments.read hoặc shift_assignments.read_all |
| Nghỉ phép / Danh sách và đơn | /leave_requests, /leave_requests/:id | TimeOff::ListLeaveRequests, FindLeaveRequest | leave.read hoặc leave.read_all; show kiểm quyền và scope |
| Bảng lương / Kỳ lương | /pay_runs, /pay_runs/:id | Payroll::ListPayRuns, FindPayRun, ReconcilePayRun, ListPayslips | payroll.read |
| Bảng lương / Tệp xuất | /payroll/exports | Payroll::ExportWorkspace | đủ payroll.read + payroll.exports.read |
| Tuyển dụng / Ứng viên | /candidates | Recruitment::ListCandidates | recruitment.read |
| Onboarding / Hồ sơ và checklist | /onboarding/cases, /onboarding/cases/:id | Onboarding::Workspace, FindCase | onboarding.read hoặc onboarding.read_all |
| Tích hợp / Nhận, kết nối | /integration | Integration::Workspace | integration.read |
| Tích hợp / Gửi | /integration/outbound | Integration::OutboundWorkspace | integration.read |
| Tích hợp / Nhật ký | /integration/audit | Integration::AuditWorkspace | đủ integration.read + integration.audit.read |
| Hệ thống / Các công ty | /system/companies | Identity::SystemCompanies | system.companies.read (SystemGrant) |
| Hệ thống / Công ty hiện tại | /manage/company | Identity::Administration (company) | company.manage |
| Hệ thống / Tài khoản | /manage/accounts | Identity::Administration (accounts) | accounts.manage |
| Hệ thống / Vai trò | /manage/roles | Identity::Administration (roles) | roles.manage |
| Hệ thống / Audit | /audit_logs | Audit::ListAuditLogs | audit.read |

Tên Query ở bảng dùng namespace rút gọn Hrm<Module>::Application::Queries. Không dùng bảng này làm source cấu hình permission. Đối chiếu class/path thực nếu đổi tên use case.

## KPI, widget, board và bộ lọc thật

| Phần dashboard | Điều kiện / đơn vị | Route helper và bộ lọc nguồn | Dòng chi tiết |
|---|---|---|---|
| Nhân viên đang hoạt động | Pundit Employee scope + status=active / người | employees_path(status: active) | employee_path hiện có |
| Đơn phép chờ duyệt | Pundit LeaveRequest scope + pending / đơn, tất cả ngày | leave_requests_path(status: pending) | leave_request_path; màn hình mới thuộc TimeOff |
| Ca đang mở | Pundit Attendance scope + checked_out_at IS NULL / ca, tất cả ngày | attendances_path(status: open) | attendance_path hiện có |
| Kỳ lương chờ chốt | Pundit PayRun scope + draft + tháng được chọn / kỳ | pay_runs_path(status: draft, period: YYYY-MM) | pay_run_path → đối soát/phiếu lương hiện có |
| Đang tiếp nhận | Onboarding scope + in_progress / hồ sơ | onboarding_cases_path(status: in_progress) | onboarding_case_path |
| Tổng quan phòng ban/ứng viên/webhook | Pundit scope, tất cả trạng thái / phòng ban, hồ sơ, sự kiện | departments_path, candidates_path, integration_path (không lọc) | giữ màn hình nguồn hiện có |
| Widget đơn phép/ca mở | 5 dòng mới nhất, cùng predicate của card | Xem tất cả dùng cùng helper/status | chỉ GET, không xử lý từ dashboard |
| Widget kỳ lương | tối đa 5 kỳ trong tháng, gồm draft/finalized | Xem tất cả giữ period, không áp status draft | mở kỳ cụ thể |
| Board tiếp nhận | tất cả trạng thái thật của CaseStateMachine; counts toàn scope | mỗi cột lọc status tương ứng | 3 dòng/cột trong 100 hồ sơ mới nhất; nguồn đã lọc phân trang25 |
| Việc tiếp theo | mục checklist chưa xong đầu tiên, không ở completed/cancelled | hồ sơ#checklist-code | form/command hoàn tất và kiểm mandatory checklist giữ nguyên |

Dashboard Overview authorize dashboard.view, repository chỉ gọi contracts module sở hữu; không SQL xuyên module. Đọc số liệu trực tiếp mỗi request; bỏ cache30s để không hứa số khớp dữ liệu nguồn đã đổi. Count và list cùng tenant/Pundit/predicate; dữ liệu vẫn có thể thay đổi sau khi trang mở, cần tải lại. Không claim snapshot giao dịch toàn ERP.

Bộ lọc web mới: Employee status(active/probation/inactive), Attendance status(open/closed), Leave status(pending/approved/rejected), Payroll status(draft/finalized)+period(YYYY-MM), Onboarding status trong state machine. Hrm::ListFilters chỉ nhận giá trị allowlist; malformed/structured status hoặc tháng không hợp lệ trả404. Company_id không chọn tenant. Pagination giữ query string. API hiện có giữ hành vi cũ, không claim thêm API filters trong đợt này.

## Backlog theo mức sẵn sàng

1. Có nền dữ liệu, cần mở rộng nghiệp vụ riêng: pipeline tuyển dụng sang hồ sơ nhân viên chưa tự provision; OT/thuế/bảo hiểm/khấu trừ và chuẩn xuất kế toán/pháp định chưa có công thức đầy đủ. Payroll hiện vẫn lương cơ bản/snapshot, ca mở và phép chờ chỉ là cảnh báo. Không thêm chỉ số giả vào dashboard.
2. Có nền tích hợp, chưa là nghiệp vụ ERP: webhook HMAC/outbox/retry và payroll descriptor bridge; adapter tạo đơn mua/bút toán/thanh toán không được suy từ webhook acknowledgement. Cần contract, grant, idempotency và transaction riêng trước menu.
3. Chưa có module/model/màn hình Rails hoàn chỉnh: mua hàng/AP, sổ cái/AR/treasury, kho/bán hàng/CRM, tài sản, dự án, thuế/pháp định, planning/forecasting. Không thêm menu rỗng hoặc copy số liệu Laravel.

## So sánh cho người chuyển từ Laravel

Laravel: route/middleware → Controller → Query/Action → Repository → Eloquent scope.
Ruby project này: route tường minh → Controller → Application::Queries → contract qua provider → ActiveRecord repository → Pundit policy_scope.
Card chỉ sinh URL bằng route helper; policy và scope tại nguồn vẫn chạy lại. Provider bind dependency, không cấp quyền. Command duyệt/chốt/checklist mới ghi dữ liệu và giữ transaction/lock/audit như trước.
