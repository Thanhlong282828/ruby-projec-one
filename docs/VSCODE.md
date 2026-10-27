# VS Code: Cmd + click / Go to Definition

Dự án dùng Ruby 3.4 trong Docker. Dev Containers cho Ruby LSP chạy cùng Ruby và gems với ứng dụng; không dùng Ruby 2.6 hệ thống trên macOS.

1. Mở thư mục gốc ruby (có Gemfile), không chỉ mở một file/module riêng.
2. Cài extension Dev Containers của Microsoft. Docker Desktop cần đang chạy.
3. Cmd+Shift+P → Dev Containers: Reopen in Container.
4. Chờ Ruby LSP của Shopify khởi động và lập chỉ mục. Extension tự được cài trong container.
5. Mở modules/attendance/app/controllers/attendances_controller.rb, Cmd+click ApplicationController hoặc dùng F12 / Go to Definition.
6. Đích là modules/platform/app/controllers/application_controller.rb.

Dev Container dùng lại compose.yaml, giữ ứng dụng tại localhost:3100 và không dừng stack khi đóng cửa sổ VS Code. Không cần đưa ruby-lsp vào Gemfile ứng dụng. Thư mục cache .ruby-lsp không được commit.

Nếu không nhảy được: chọn Output → Ruby LSP, kiểm tra Ruby đang là 3.4, chờ indexing hoàn tất hoặc chạy Ruby LSP: Restart. Cmd+click vào class/method khác với chuỗi route như "attendances#create"; hỗ trợ chuỗi phụ thuộc tính năng Rails của extension.

Nguồn: https://shopify.github.io/ruby-lsp/ và https://code.visualstudio.com/docs/devcontainers/create-dev-container

Đã kiểm tra trực tiếp trên VS Code: Cmd+click ApplicationController ở AttendancesController mở đúng modules/platform/app/controllers/application_controller.rb. Ruby LSP v0.26.11 và Rails add-on v0.4.8 hoạt động với Ruby 3.4.12 trong container.
