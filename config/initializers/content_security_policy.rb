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
