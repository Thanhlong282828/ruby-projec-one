# Menu ERP và luồng Dashboard → nguồn

Phạm vi: source Rails 13 Engines. LaravelDji chỉ tham chiếu cách gom miền, không chứng nhận ngang tính năng. Đã đọc tài liệu read-only `Desktop/laraveldji/admin/docs/erp-navigation-domain-map.md` và `erp-sidebar-feature-audit.md`: giữ nhóm có con được phép, không menu trống. Bản kiểm chứng cụ thể nằm trong VERIFICATION.md.

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
| Mua hàng / Nhà cung cấp | /procurement/suppliers | Procurement::Suppliers, FindSupplier | procurement.suppliers.read; tạo/sửa cần create/update riêng |
| Mua hàng / Đơn mua hàng | /procurement/orders | Procurement::Orders, FindOrder | procurement.orders.read |
| Mua hàng / Phiếu chờ lập PO | /procurement/requests?status=approved&view=awaiting_po | Procurement::Workspace | orders.read + orders.create và Pundit PurchaseRequest scope |
| Mua hàng / Yêu cầu mua | /procurement/requests | Procurement::Workspace, FindRequest | procurement.requests.read (của mình) hoặc read_all (công ty) |
| Mua hàng / Yêu cầu của tôi | /procurement/requests?view=mine | Procurement::Workspace | cùng quyền đọc; thêm created_by=current_user |
| Mua hàng / Chờ tôi duyệt | /procurement/requests?status=submitted&view=review | Procurement::Workspace | đủ procurement.requests.read_all + review, loại phiếu tự tạo |
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
| Phiếu đã duyệt chờ lập PO | approved + cùng Pundit request scope + chưa có PO / phiếu | purchase_requests_path(status: approved, view: awaiting_po) | purchase_request_path → tạo hoặc xem PO; count/list dùng cùng contract |
| Yêu cầu mua chờ duyệt | submitted + Pundit company scope + không tự tạo / phiếu, mọi ngày cần hàng | purchase_requests_path(status: submitted, view: review) | purchase_request_path, giữ bộ lọc; widget 5 phiếu mới nhất |
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
3. Mua hàng đã có yêu cầu mua, danh mục nhà cung cấp và PO nháp → phát hành; nhận hàng, đối chiếu hóa đơn/AP chưa có. Các miền chưa có module/model/màn hình Rails hoàn chỉnh: sổ cái/AR/treasury, kho/bán hàng/CRM, tài sản, dự án, thuế/pháp định, planning/forecasting. Không thêm menu rỗng hoặc copy số liệu Laravel.

## So sánh cho người chuyển từ Laravel

Laravel: route/middleware → Controller → Query/Action → Repository → Eloquent scope.
Ruby project này: route tường minh → Controller → Application::Queries → contract qua provider → ActiveRecord repository → Pundit policy_scope.
Card chỉ sinh URL bằng route helper; policy và scope tại nguồn vẫn chạy lại. Provider bind dependency, không cấp quyền. Command duyệt/chốt/checklist mới ghi dữ liệu và giữ transaction/lock/audit như trước.

## Mua hàng — yêu cầu mua đã có source

Engine `modules/procurement` sở hữu model, Policy, Commands/Queries, contracts, persistence, migration và view. Entry `modules/procurement/lib/hrm_procurement.rb` nạp Engine; `providers/procurement_service_provider.rb` đăng ký 2 repository và catalog quyền (không thay Policy). Routes tường minh ở `modules/procurement/config/routes/procurement.rb`.

Danh sách hỗ trợ `q` (mã/tiêu đề, tối đa 120 ký tự), `status` (draft/submitted/approved/rejected), `view` (mine/review), `page`; chi tiết thêm `history_page`. Không nhận tenant từ client. Liên kết quay lại, sửa/lưu, gửi/duyệt giữ ngữ cảnh danh sách; trang rỗng có xóa lọc và tạo nếu được phép. Menu chọn đúng queue bằng `aria-current`, không cùng đánh dấu cả ba mục có chung pathname.

Nháp → sửa dòng → gửi xác nhận → duyệt hoặc từ chối có lý do → lịch sử. Mỗi dòng tính `BigDecimal(quantity) * unit_price`, làm tròn HALF_UP về nguyên VND rồi cộng tổng tại server. Số lượng tối đa 3 số lẻ; đơn giá nguyên VND 12 chữ số; 1–50 dòng. Không suy từ cột salary_cents sang đơn vị tiền mới. Nội dung trình giữ nguyên sau gửi; maker không tự duyệt. Version cũ trả409; kiểm quyền hiện hành lại bằng locking reads trong transaction; audit/outbox và lịch sử rollback cùng mutation. Mục đích/lý do được mã hóa, payload form bị lọc khỏi log. Realtime metadata yêu cầu read_all, không phát cho người chỉ đọc phiếu của mình.

Quyền MySQL có 6 key dưới `procurement.requests.`: read, read_all, create, update, submit, review. Mặc định provision admin/manager đủ 6; employee/hr đọc của mình + tạo/sửa/gửi. Custom role không tự thêm quyền; deny trực tiếp vẫn thắng. Người có read_all có thể xem nhưng chỉ owner được sửa/gửi nháp; duyệt cần cả read_all+review, khác maker. Không có delete/bulk-approve/API mới trong lát cắt này.

So sánh Laravel → Rails theo từng bước:

| Laravel quen dùng | Rails trong module Mua hàng | Nhiệm vụ |
|---|---|---|
| Route + Controller | config/routes/procurement.rb → RequestsController | GET mở màn hình; POST/PATCH gọi command, không SQL ở controller |
| FormRequest | PurchaseRequestParameters + RequestContent/RequestFilters | allowlist field, kiểm kiểu và tiền chính xác; không tin company/total client |
| Service Provider bind interface | ProcurementServiceProvider → Hrm::Container | nối contract với ActiveRecord repository; không cấp quyền |
| Policy/middleware permission | PurchaseRequestPolicy + Pundit scope | kiểm permission từ MySQL và công ty của phiên |
| Action/Command tạo, duyệt | CreateRequest/UpdateRequest/SubmitRequest/DecideRequest | entrypoint nghiệp vụ; ngoài HTTP vẫn kiểm quyền |
| Repository Eloquent + transaction/lockForUpdate | ActiveRecordWriteRepository + transaction/.lock | khóa identity/grants/phiếu, kiểm version/trạng thái hiện tại, ghi đồng bộ |
| Eloquent model/observer | PurchaseRequest/Line/Event + ObservableRecord | quan hệ/validation, audit+outbox, lịch sử phiên bản |
| Blade và route() | ERB + purchase_requests_path/purchase_request_path | giao diện tiếng Việt, KPI chỉ điều hướng tới Query nguồn |

Nhập kho và trả nhà cung cấp đã được bổ sung bên dưới. Đối chiếu hóa đơn, công nợ và thanh toán vẫn cần contract/quyền/transaction riêng; phát hành PO chưa tự tạo các nghiệp vụ đó.

## Đơn mua hàng (PO) từ phiếu đã duyệt

PO nằm trong Engine procurement hiện có, vẫn 13 Engines / 40 bindings. Contracts Read/Write hiện có bổ sung methods cho supplier/order; hai implementation include `OrderReads` và `OrderWrites`. Không SQL ở Controller, không query xuyên Engine tại Dashboard.

| Bước | Route / use case Rails | So sánh Laravel | Quy tắc |
|---|---|---|---|
| Nhà cung cấp | /procurement/suppliers; Suppliers/FindSupplier/SaveSupplier | Eloquent catalog + FormRequest + Policy/Action | code duy nhất trong company; name/status; create/update riêng, optimistic version |
| Phiếu chờ lập PO | /procurement/requests?status=approved&view=awaiting_po; Workspace | scoped approved + whereDoesntHave(order) | cùng predicate với KPI, cần đọc phiếu + orders.read/create |
| Form từ nguồn | GET /procurement/orders/new?purchase_request_id=ID; OrderSource | scoped findOrFail + options query | source phải approved; chỉ options supplier active cùng company; chiếu code/name/ID theo quyền tạo PO |
| Tạo nháp | POST /procurement/orders; CreateOrder | DB::transaction + lockForUpdate + unique index | khóa IAM/company/grants, khóa source; tối đa một PO/company/source. Gửi lặp trả PO gốc, không đổi supplier/ngày/giá |
| Sửa nháp | GET edit + PATCH /procurement/orders/:id; UpdateOrder | Action + transaction + optimistic lock | giữ vendor/source/snapshot/số lượng; chỉ ngày giao, đơn giá và lý do. Đúng tập source_line_id, không lặp/thêm/bớt dòng |
| Phát hành | POST /procurement/orders/:id/issue; IssueOrder | Policy + locked state transition + Observer | quyền orders.issue riêng + orders.read; version/state/current supplier active kiểm dưới khóa; phát hành rồi khóa nội dung |
| Lịch sử | GET /procurement/orders/:id; FindOrder | eager-loaded show + audit projection | actor/thời điểm/version/lý do mã hóa, 25 bước/trang; source link chỉ hiện nếu có quyền đọc phiếu |

Quyền MySQL mới: `procurement.suppliers.{read,create,update}` và `procurement.orders.{read,create,update,issue}`. Provision admin/manager; employee/hr/custom role không tự cấp quyền mới. Không suy quyền từ enum runtime. Người chỉ được tạo PO có thể chọn projection supplier active tối thiểu qua OrderSource; không vì vậy được vào màn hình quản lý supplier. Tạo PO cần đọc chính phiếu nguồn; đọc PO dùng grant PO riêng trong cùng company. Có quyền sửa PO không đồng nghĩa quyền phát hành. Không thêm maker-checker cho PO trong đợt này; maker-checker của bước duyệt phiếu vẫn giữ nguyên.

`PurchaseOrder` lưu snapshot mã/tiêu đề/tổng phiếu và mã/tên supplier tại lúc tạo, currency VND. `PurchaseOrderLine` giữ FK đến từng source line, snapshot mô tả/đơn vị/số lượng/đơn giá nguồn và giá đặt. Composite FK chặn ghép sai company/source/parent; unique `(company_id,purchase_request_id)` chặn trùng, kể cả SQL bypass. Số lượng không cho sửa; giá đặt nguyên đồng, tính BigDecimal × quantity, từng dòng HALF_UP rồi cộng. Chi tiết hiển thị dự toán, tổng đặt và chênh lệch có dấu. Một dòng đổi giá cũng cần lý do trước phát hành, kể cả tổng chênh bằng 0. Reason/history note mã hóa, form payload bị lọc khỏi log; audit/outbox chỉ metadata cùng transaction, rollback nếu journal lỗi.

Supplier có thể đổi mã/tên/status; snapshot PO lịch sử không thay đổi. Supplier ngừng hoạt động không có trong options tạo mới và bị chặn lúc phát hành (cả khi form mở trước lúc ngừng). PO nháp giữ supplier đã chọn; nếu cần phát hành sau khi supplier ngừng, người có quyền phải xử lý lại catalog theo nghiệp vụ, không có tự đổi vendor hoặc bypass. Menu/KPI dùng company từ profile đăng nhập; không nhận company_id client. PO issued vẫn được đọc khi supplier inactive. Không có delete/cancel/invoice/AP hoặc API PO mới; nhận hàng được bổ sung trong lát cắt bên dưới.

Danh sách PO hỗ trợ `q` mã/tiêu đề, `status=draft|issued`, `page`; supplier hỗ trợ q mã/tên, status active/inactive, page. Cả hai 25 dòng/trang; PO detail/edit/back links giữ q/status/page, lịch sử thêm history_page. Queue `awaiting_po` và `review` hiển thị đúng trạng thái cố định, tránh lọc mâu thuẫn. KPI 0 vẫn mở queue rỗng có giải thích và reset. Tạo PO chỉ ở form/command; KPI/link không tự ghi hoặc phát hành.

Trên MySQL/Rails hiện tại, DECIMAL scale 0 có thể đọc thành Integer: form dùng `.to_i.to_s` cho đơn giá VND đã được chuẩn hóa nguyên đồng; quantity scale 3 vẫn BigDecimal. Không gọi Integer#to_s("F"), không dùng Float để tính tiền.


## Nhận hàng từng phần từ PO đã phát hành

Menu **Mua hàng → Nhận hàng / PO còn chờ nhận** dùng cùng registry sidebar và Dashboard. Trong Engine procurement hiện có, vẫn 13 Engines / 40 bindings; không tạo nghiệp vụ tồn kho giả.

| Màn hình / thao tác | Route / use case | Điều kiện và dữ liệu nguồn |
|---|---|---|
| KPI PO còn chờ nhận | `/procurement/orders?delivery=pending`; Orders → order_workspace | orders.read; PO issued, tồn tại dòng có quantity lớn hơn tổng nhận recorded. Cùng predicate cho count và danh sách; q/status/page giữ trên link chi tiết/quay lại. 0 vẫn mở danh sách rỗng |
| PO chi tiết | FindOrder | giữ status issued, snapshot giá/số lượng gốc; tổng nhận theo từng dòng, còn lại và Chưa nhận/Nhận một phần/Đã nhận đủ. Quá ngày giao chỉ khi expected_on < hôm nay và còn hàng |
| Form nhận | GET `/procurement/receipts/new?purchase_order_id=ID`; ReceivingSource | receipts.read + receipts.create + orders.read; PO issued cùng company; Đặt / Đã nhận / Còn lại / Nhận lần này. Để trống/0 để bỏ qua dòng, ít nhất một dòng dương, tối đa 3 số lẻ |
| Ghi nhận | POST `/procurement/receipts`; ReceiveOrder | kiểm quyền DB hiện hành dưới khóa IAM/company/role/grants → PO → dòng PO theo ID → phiếu/dòng nhận. Đọc hiện hành bằng locking reads, không dùng SUM theo snapshot cũ. Từ chối vượt phần còn lại |
| Danh sách phiếu | GET `/procurement/receipts`; Receipts | receipts.read, scope company + recorded; tìm mã, phân trang 25 |
| Phiếu và lịch sử | GET `/procurement/receipts/:id`; FindReceipt | receiver ID/ngày nhận/thời điểm ghi/delivery reference mã hóa + các dòng nguồn. Link PO cần orders.read, link yêu cầu mua cần quyền đọc đúng phiếu nguồn |

GoodsReceipt/GoodsReceiptLine lưu riêng; không sửa PurchaseOrder đã issued. Dòng nhận FK composite đến đúng PO line, header/receiver cùng company. Ngày nhận do người nhận nhập, created_at là thời điểm ghi trên server. Số lượng BigDecimal, không dùng Float; qty DECIMAL(9,3), CHECK >0. Dòng bỏ qua không được lưu thành dòng 0. Không cho thêm/sửa/xóa qua public route sau ghi nhận.

Idempotency key ngẫu nhiên của form, 16–64 ký tự ASCII, unique case-sensitive `(company_id,idempotency_key)`. Digest canonical gồm PO ID/ngày nhận/reference/tập dòng ID và decimal đã normalize, không gồm company từ client. Cùng khóa và nội dung trả phiếu gốc, kể cả PO đã nhận đủ; cùng khóa khác PO/ngày/reference/số lượng trả 409. Dù replay vẫn kiểm grant hiện hành và scope trước trả kết quả. Không đưa khóa vào URL hoặc log; toàn payload form được filter.

Ghi header nội bộ `recording`, autosave lines, chốt `recorded`, audit/outbox chung transaction. Không có màn hình/command commit riêng trạng thái recording. MySQL trigger kiểm issued, ownership qua FK, cấm sửa/xóa trực tiếp receipt/lines đã ghi, chặn thêm dòng sau seal và kiểm tổng nhận khi seal. MySQL không cho locking SELECT trên chính bảng đang INSERT: kiểm tổng chuyển sang header seal với locking reads; không bỏ kiểm tổng hoặc transaction. Những dòng recording do SQL đặc quyền bỏ dở vẫn được tính như phần đã giữ ở write guard, không tự cho nhận vượt; cần operator điều tra, không tự xóa lịch sử.

Quyền MySQL mới `procurement.receipts.read/create`; provision admin/manager, không runtime role bypass. Đọc tiến độ giao thuộc orders.read, đọc chứng từ nhận thuộc receipts.read. Realtime goods_receipt.* yêu cầu receipts.read và realtime.read hiện hành. Audit/outbox chỉ metadata; delivery reference encrypt at rest. Các FK cascade từ parent giữ cơ chế cleanup đặc quyền hiện có: SQL đặc quyền xóa PO có thể cascade lịch sử; ứng dụng không có delete PO/receipt và model chặn. Không xem trigger là cơ chế chống root DB phá dữ liệu.

Nhận hàng chỉ là tiến độ giao PO; nhập kho từ phiếu nhận đã bổ sung ở lát cắt bên dưới. Backlog tiếp: vị trí kho/lô/serial, chuyển kho, kiểm kê, đảo bút toán, hóa đơn/đối soát ba bên, công nợ và thanh toán.


## Nhập kho từ phiếu nhận đã ghi nhận

Source chưa có inventory catalog/ledger trước e47812f. Lát cắt mới thuộc Engine procurement hiện có (13 Engines /40 bindings), có menu **Kho** riêng; chưa tách Engine inventory hoặc tự tạo nghiệp vụ invoice/AP.

| Màn hình / KPI | Route / Query | Quyền và predicate |
|---|---|---|
| Chờ nhập kho / Phiếu nhận chờ nhập kho | GET `/inventory/receipts/pending`; PendingStockReceipts → pending_stock_workspace | inventory.receipts.read/post + procurement.receipts.read. GoodsReceipt recorded cùng company chưa có StockReceipt. Count và danh sách dùng chung scope/predicate; KPI0 mở đúng danh sách rỗng |
| Lịch sử nhập | GET `/inventory/receipts`; StockReceipts | inventory.receipts.read; chỉ posted, company từ actor; q mã phiếu/mã kho, page25 |
| Form ánh xạ | GET `/inventory/receipts/new?goods_receipt_id=ID`; StockSource | quyền tạo/đọc nguồn; chọn một kho, từng GR line → StockItem đúng đơn vị. Kho/SKU active cùng company. Tìm mã/tên, options tối đa500 mỗi loại; không tin lựa chọn cũ lúc ghi |
| Ghi sổ | POST `/inventory/receipts`; PostStockReceipt | khóa IAM/company/grants → receipt → entry hiện có → warehouse → SKU theo ID → source PO lines. Policy authoritative sau khóa receipt khi grant locks còn giữ. Unique company/receipt, digest kho+mapping canonical. Toàn phiếu, số lượng lấy server từ GR line |
| Phiếu nhập / chuỗi nguồn | GET `/inventory/receipts/:id`; FindStockReceipt | inventory.receipts.read, posted/same-company; actor/time, warehouse/item snapshots, received line/PO line IDs; link PR→PO→GR→IN chỉ mở khi được đọc nguồn tương ứng |
| Tồn theo kho | GET `/inventory/balances?warehouse_id=ID`; StockBalances | inventory.balances.read; SUM nguồn UNION ALL nhập posted (+) và trả posted (−), GROUP warehouse/SKU ID; không có cột tồn cập nhật tay. Lọc warehouse vẫn company-scoped; phân trang25 cặp, count subquery theo group |
| Danh mục kho / mã hàng | GET/POST `/inventory/warehouses`, `/inventory/items`, GET edit/PATCH/PUT individual | inventory.catalog.read/manage; search/status/page25; optimistic version, code duy nhất trong company, trạng thái active/inactive |

Warehouse/StockItem có code ổn định; unit StockItem bất biến từ lúc tạo, không tự đổi/quy đổi theo mô tả PO. ID mã hàng là khóa cộng tồn, description chỉ tham chiếu. Tên/status được sửa; ngừng hoạt động vẫn có trong lịch sử/tồn nhưng không chọn để ghi mới. Header lưu snapshot mã/tên kho, movement lưu snapshot mã/tên/unit SKU và exact source quantity. Composite FK giữ company, kho, receipt/line và PO line đúng nguồn. Phiếu nhận và PO không cập nhật/touch khi nhập.

Mỗi GoodsReceipt recorded được nhập đủ tất cả dòng vào một kho trong một lần. Nội bộ tạo StockReceipt posting + autosave movements rồi seal posted cùng transaction; không public API để commit riêng posting. Seal trigger kiểm đủ số dòng, unique movement/source + FK + exact quantity trigger đảm bảo không thiếu/lặp/thêm hoặc sửa quantity. Audit/outbox cả create/seal chung transaction; lỗi journal sau ghi movements vẫn rollback hết. Tồn chỉ tính posted. Không có delete/update app route cho ledger; trigger chặn sửa/xóa trực tiếp entry/movements sau ghi. Như cơ chế cha PO/GR hiện có, SQL đặc quyền xóa parent có thể cascade lịch sử; không coi trigger là bảo vệ khỏi root DB. Posting bỏ dở bởi SQL đặc quyền cần operator xử lý, không tự reset/xóa.

Replay cùng receipt, kho và tập mapping (chuẩn hóa ID/sắp xếp dòng) trả entry gốc nếu còn inventory.receipts.read; đây là đọc lại nên không tạo movements/audit/outbox và không đòi catalog còn active hoặc grant post còn giữ. Khác kho/mapping trả409. Nếu read bị thu hồi, replay bị từ chối. Ghi mới luôn cần post+entry.read+receipt.read hiện hành; source unrecorded bị từ chối. Không đưa quantity, company, status, posted_by/at từ client vào dữ liệu ghi.

Catalog read/manage, receipts.read/post, balances.read là grants MySQL riêng, provision admin/manager, không suy từ role enum runtime. Người được ghi nhưng thiếu catalog.read chỉ nhận projection tối thiểu active kho/SKU cho form, không vào trang quản lý catalog. Người chỉ xem tồn không tự được mở chứng từ nguồn. Realtime warehouse./stock_item. yêu cầu catalog.read; stock_receipt. yêu cầu receipts.read, kèm realtime.read hiện hành. Payload form/catalog được filter khỏi log; outbox/audit chỉ metadata.

Xuất/chuyển/kiểm kê, giá vốn/định giá tồn, lô/serial/vị trí, chuyển đổi đơn vị, đảo bút toán, invoice/AP/đối soát ba bên còn backlog. Tồn gồm nhập từ GR trừ trả nhà cung cấp cộng đảo phiếu trả đã ghi sổ, chưa phải đầy đủ WMS hoặc kế toán kho.

## Truy vết tồn kho theo cặp kho / mã hàng

- Từ số lượng ở `/inventory/balances`, mở `/inventory/ledger?warehouse_id=ID&stock_item_id=ID`. Route helper `stock_ledger_path`; Query `HrmProcurement::Application::Queries::StockLedger` gọi ReadRepositoryInterface → StockReads. Không truy vấn trong controller/view.
- Quyền `inventory.balances.read`; company lấy từ actor. Cả warehouse và stock_item phải tồn tại trong công ty hiện hành, ID malformed/cross-company trả 404. Dùng chung ReturnReads#signed_stock_scope với Tồn theo kho: UNION ALL nhập posted, trả posted và đảo phiếu trả posted, đúng cặp kho/mã hàng; tổng tất cả trang, 25 dòng/trang. Thứ tự posted_at giảm dần, loại chứng từ rồi ID giảm dần để ổn định khi trùng thời điểm.
- Dòng hiển thị thời điểm ghi sổ, mã phiếu nhập/trả, lượng có dấu, snapshot mã/tên/đơn vị và tham chiếu dòng nhận/PO. Link phiếu nhập cần `inventory.receipts.read`, link trả cần `inventory.returns.read`, link đảo cần `inventory.return_reversals.read`; thiếu grant vẫn thấy số biến động nhưng không có link. Quyền đọc tồn không tự cấp quyền mở chứng từ. Thu quyền đọc tồn chặn cả URL trực tiếp và Query.
- Phân trang giữ warehouse_id + stock_item_id. Cặp hợp lệ chưa nhập hiển thị tổng 0/danh sách rỗng; không biến ID khác công ty thành màn hình rỗng. Không có mutation, export hay lũy kế giả. Sổ gồm nhập từ GR (+), trả nhà cung cấp (−) và đảo phiếu trả (+), chưa phải WMS đầy đủ.
- Bảng ledger có region tên “Các dòng biến động kho”, `tabindex=0` và focus-visible; Tab vào rồi dùng trái/phải để cuộn cột trong màn hình hẹp. Khung bảng cuộn riêng, không kéo cả phần tổng/link về kho.


## Trả hàng nhà cung cấp từ phiếu nhập đã ghi sổ

Engine procurement giữ Module + MVC + CQRS. Menu **Kho → Trả nhà cung cấp** chỉ hiện với grant MySQL `inventory.returns.read`. Không mở rộng Sorbet strict khỏi 21 file hiện có.

| Màn hình / thao tác | Route → Controller → Query/Command → Repository | Quyền và phạm vi |
|---|---|---|
| Lịch sử trả | GET `/inventory/returns?q=...&page=...` → StockReturnsController#index → StockReturns → stock_return_workspace | returns.read; posted, company từ actor; tìm mã phiếu/mã NCC, 25 phiếu/trang |
| Form theo phiếu nhập | GET `/inventory/returns/new?stock_receipt_id=ID` → StockReturnSource → stock_return_source | returns.read + returns.post + receipts.read; nguồn posted cùng công ty; hiện Đã nhập/Đã trả/Còn được trả/Trả lần này |
| Ghi sổ | POST `/inventory/returns` → PostStockReturn → post_stock_return! | kiểm quyền hiện hành sau khóa IAM/company/grants; server lấy toàn bộ kho/SKU/đơn vị/NCC từ nguồn |
| Chi tiết | GET `/inventory/returns/:id` → FindStockReturn → find_stock_return! | returns.read; company/posted scope; nguồn chỉ có link khi còn receipts.read |
| Tồn / sổ | StockBalances và StockLedger → StockReads + ReturnReads#signed_stock_scope | balances.read, cùng UNION đã scope; cộng nhập posted và trừ trả posted; không đòi quyền đọc từng chứng từ để tính đúng tồn |

Mỗi StockReturn liên kết một StockReceipt posted; StockReturnLine liên kết đúng StockMovement gốc. Dòng gốc vẫn là số dương và vẫn đối chiếu exact quantity với GR; bảng trả riêng giữ lượng dương DECIMAL(9,3). Chỉ projection đọc trả hiển thị âm. Nhiều lần trả hoặc nhiều dòng cùng SKU vẫn giới hạn **theo từng movement gốc**, không lấy tồn toàn SKU để cấp quyền trả. BigDecimal, tối đa 3 chữ số lẻ; blank không chọn dòng, 0/âm/Float/sai định dạng bị từ chối. Lý do bắt buộc, mã hóa at rest; form/key/reason không ghi log.

Ghi mới: khóa IAM → phiếu nhập → idempotency hiện có → movements theo ID → các dòng trả hiện hành; dùng locking read dưới MySQL REPEATABLE READ, không dùng SUM consistent-read từ snapshot cũ. Header posting, lines, seal posted, audit và outbox cùng transaction/savepoint. Unique case-sensitive `(company_id,idempotency_key)` là hàng rào cuối. Retry unique lỗi tối đa một lần ngoài savepoint, đi lại toàn đường kiểm quyền. Cùng key/source/reason/tập dòng đã normalize trả phiếu cũ nếu còn returns.read, không cần giữ quyền ghi; khác payload/source trả409. Đổi quyền xem thì replay bị từ chối. Không tự cập nhật/touch PO/GR/IN gốc.

Composite FK ràng buộc company/phiếu/kho/dòng/SKU đúng nguồn. Sáu trigger mới bảo vệ insert, seal và bất biến; kiểm tổng ở seal header, không SUM/khóa đọc chính bảng đang INSERT trong trigger dòng. FK mới dùng RESTRICT, nên cả xóa nguồn cha có cascade cũ cũng bị chặn khi đã có phiếu trả. Model chặn sửa/xóa, không có route edit/delete. Tài khoản DB đặc quyền vẫn có thể DROP/TRUNCATE hoặc đổi trigger, không tuyên bố chống root DB.

Catalog đã inactive vẫn dùng snapshot nguồn để trả hàng lịch sử; không chọn kho/SKU/NCC mới. Dòng posting do operator SQL bỏ dở giữ chỗ số đã trả và fail closed; tồn chỉ tính posted. App không có luồng commit riêng posting. Cần operator xử lý pending đặc quyền, không tự xóa lịch sử. Realtime stock_return.* cần returns.read cùng generic realtime.read, không phát lý do/raw payload.

Phiếu nhập hiện nút Trả hàng chỉ khi đủ quyền và còn lượng. Phiếu trả có nguồn IN và link tồn/sổ theo grant. Bảng form/chi tiết/sổ cuộn ngang riêng, region có tên và tabindex; submit bằng Tab/Enter. Giữ warehouse_id/SKU khi phân trang và quay về tồn; tổng tính toàn bộ kết quả. Không có định giá, invoice/AP, xuất/chuyển, đảo phiếu nhập/đảo chứng từ khác hoặc GHCR release trong lát cắt này. Đảo phiếu trả đã bổ sung ở phần tiếp theo.


## Đảo toàn bộ phiếu trả nhà cung cấp đã ghi sổ

Thuộc Engine procurement, dùng lại Module + MVC + CQRS. Giữ nguyên StockReceipt/StockMovement và StockReturn/StockReturnLine; không sửa trạng thái hay số lượng nguồn. Chỉ đảo toàn bộ một StockReturn posted, tối đa một lần, vì sửa sai ghi sổ, lý do bắt buộc mã hóa at rest. Không định giá, AP/invoice, đảo phiếu nhập, hoặc release GHCR.

| Màn hình / thao tác | Route → Query/Command → persistence | Quyền |
|---|---|---|
| Kho → Đảo phiếu trả | GET `/inventory/return-reversals?q=...&page=...` → StockReturnReversals → reversal_reads#stock_return_reversal_workspace | inventory.return_reversals.read; company của actor, posted, tìm mã phiếu/mã NCC;25/trang |
| Xác nhận số lượng cộng lại | GET `/inventory/return-reversals/new?stock_return_id=ID` → StockReturnReversalSource | reversal.read + reversal.post + inventory.returns.read; nguồn posted và chưa có đảo |
| Ghi đảo toàn bộ | POST `/inventory/return-reversals` → PostStockReturnReversal → reversal_writes#post_stock_return_reversal! | cả ba grant hiện hành cho ghi mới; input chỉ ID nguồn/key/lý do, toàn bộ lượng/kho/SKU/NCC lấy từ nguồn |
| Chi tiết đảo | GET `/inventory/return-reversals/:id` → FindStockReturnReversal | reversal.read, same-company/posted; link về RT chỉ khi returns.read |
| Phiếu trả → Đảo phiếu / Xem chứng từ đảo | FindStockReturn → ReturnReads | nút theo create? và chưa có chứng từ đảo, link theo reversal.read; GET form cũ/POST hai lần đều được server kiểm lại |
| Tồn theo kho / Sổ biến động | ReturnReads#signed_stock_scope dùng chung StockReads | balances.read: UNION ALL IN(+), RT(−), RR(+); tên loại phân biệt hai dấu cộng, không cần quyền đọc chứng từ để thấy lượng; link từng loại dùng grant riêng |

Hai grant thật trong MySQL là `inventory.return_reversals.read` và `.post`; bảng trên viết tắt reversal.read/post. Defaults provision admin/manager, không bypass role runtime. `stock_return_reversal.*` realtime metadata đòi reversal.read cùng generic realtime.read; không chứa raw reason.

**Lượng trả ròng và khóa:** ReturnQuantities#net_returned_quantities dùng chung reader và writer trả/đảo. Tổng return lines (kể cả posting giữ chỗ) trừ reversal lines có header posted. Unique từng dòng đảo đảm bảo không trừ hai lần. Ghi trả và ghi đảo đều khóa IAM/company/grants → StockReceipt gốc trước các chứng từ/dòng nghiệp vụ; khóa movement theo ID rồi locking reads dữ liệu ròng hiện hành. Reversal writer còn khóa RT nguồn và kiểm net đủ để khôi phục. Tránh consistent-read SUM từ snapshot RR cũ. Giữ savepoint requires_new và uncached auth theo nền hiện tại.

Chứng từ RR posting → tạo toàn bộ dòng → seal posted, audit và outbox cùng transaction. Khóa key case-sensitive `(company_id,idempotency_key)`; digest gồm RT ID/lý do đã chuẩn hóa, vì toàn bộ dòng nguồn bất biến. Replay cùng nội dung trả RR cũ nếu còn reversal.read, không cần giữ quyền ghi/đọc RT; khác nguồn/lý do409. Key mới trên RT đã có đảo409. Bắt unique ngoài savepoint, retry tối đa một lần và đi lại auth/lookup/conflict. Unique `(company_id,stock_return_id)` là hàng rào cuối, giữ cả khi hai thao tác khác key.

**MySQL:** composite FK RESTRICT ràng buộc header RR với RT/company/IN/kho, dòng RR với header và chính return line/company/IN/kho/SKU/movement. Mỗi dòng đảo dương DECIMAL(9,3), đúng nguyên lượng/snapshot/unit của dòng trả. Guard seal đòi đủ chính xác mọi dòng nguồn, không cho partial đảo; trigger dòng không SUM chính bảng đang INSERT. Sáu guard mới, thay guard seal RT để dùng lượng ròng sau RR posted. Header/lines đã ghi không sửa/xóa ở model và DB. Parent/source deletion cũng bị RESTRICT; không claim bảo vệ khỏi root có DROP/TRUNCATE/DDL. Migration thay trigger cần cutover có dừng đường ghi khi triển khai thật; đợt này chỉ MySQL test riêng, chưa deploy.

Ví dụ: IN4+IN6=10 → RT3=7 → RR3=10, IN4 lại được trả4. Nếu RT3 và RT1 đã ghi, chỉ đảo RT3 thì tồn9, IN4 còn được trả3; RT1 vẫn có hiệu lực. Chưa seal RR không được cộng tồn hoặc khôi phục lượng. IN/RT giữ lịch sử ban đầu, sổ có cả−3/+3 thay vì xóa dòng−3.

Form xác nhận tiếng Việt không cho sửa lượng, nêu tác động cộng tồn và mục đích sửa sai; Tab/Enter submit. Form/chi tiết/sổ có region cuộn với tabindex/aria-label/focus-visible. Bộ lọc kho/SKU giữ khi phân trang/quay lại; tổng tính toàn bộ kết quả, kể cả trang rỗng. Trên IN và form trả ghi rõ “Đã trả ròng” để không nhầm tổng lịch sử với lượng còn hiệu lực. Backlog còn đảo IN/chứng từ khác, định giá tồn, hóa đơn/công nợ, xuất/chuyển/kiểm kê và trả từng phần của phiếu đảo (không hỗ trợ).
