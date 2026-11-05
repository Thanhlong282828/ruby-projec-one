Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.font_src :self, "https://fonts.gstatic.com"
  policy.style_src :self, "https://fonts.googleapis.com"
  policy.script_src :self
  policy.img_src :self, :data
  policy.connect_src :self
  policy.object_src :none
  policy.base_uri :self
  policy.frame_ancestors :none
end
# Đoạn code này đang cấu hình Content Security Policy (CSP) trong Ruby on Rails.
#
# CSP là một cơ chế bảo mật của trình duyệt, giúp giới hạn những nguồn mà website được phép tải JavaScript, CSS, hình ảnh, font chữ và các tài nguyên khác.
#
# Mục đích chính là giảm nguy cơ Cross-Site Scripting (XSS), tải mã độc từ nguồn không được phép và một số kiểu tấn công chèn nội dung.


# Luồng hoạt động của CSP
                          # Rails Backend
                # Trả HTTP Response kèm Content-Security-Policy
                                # v
                        # Browser kiểm tra CSP
                # Nguồn tài nguyên có được cho phép không?
                #  v                                #  v
              # Được phép                         # Bị chặn
           # Tải tài nguyên                 # Không tải tài nguyên


# Directive	                      Ý nghĩa
# default_src :self       	Mặc định chỉ cho tải tài nguyên từ cùng origin
# font_src	                Cho phép font từ website và Google Fonts CDN
# style_src	                Cho phép CSS từ website và Google Fonts
# script_src :self	        Chỉ cho tải JavaScript từ cùng origin
# img_src :self, :data    	Cho phép hình ảnh cùng origin và Data URL
# connect_src :self	        Giới hạn kết nối Fetch, AJAX, WebSocket đến cùng origin
# object_src :none	        Chặn các nội dung nhúng dạng <object>, <embed>
# base_uri :self	          Giới hạn URL được khai báo qua thẻ <base>
# frame_ancestors :none	    Không cho website khác nhúng trang này bằng iframe
