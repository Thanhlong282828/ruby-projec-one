module SensitiveResponseHeaders
  extend ActiveSupport::Concern
  included do
    before_action :disable_sensitive_response_caching
  end
  private
  def disable_sensitive_response_caching
    response.headers["Cache-Control"] = "no-store, private"
    response.headers["Pragma"] = "no-cache"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
  end
end
