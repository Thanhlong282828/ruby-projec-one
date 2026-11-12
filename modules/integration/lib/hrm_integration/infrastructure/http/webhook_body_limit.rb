require "stringio"
module HrmIntegration
  module Infrastructure
    module Http
      # Boot-loaded middleware must not retain reloadable model/service instances.
      class WebhookBodyLimit
        def initialize(app) = @app = app
        def call(env)
          path = Rack::Utils.unescape_path(env.fetch("PATH_INFO", "")).squeeze('/')
          return @app.call(env) unless env["REQUEST_METHOD"] == "POST" && path.start_with?("/webhooks/integration/")
          type = env.fetch("CONTENT_TYPE", "").split(";", 2).first.to_s.strip.downcase
          return error(415, "json_required") unless type == "application/json"
          limit = HrmIntegration::Domain::Services::WebhookSignature::MAX_BYTES
          body = env["rack.input"]&.read(limit + 1).to_s
          return error(413, "body_too_large") if body.bytesize > limit
          # Logging instrumentation asks for request parameters before controller actions.
          # Suppress automatic JSON parsing; signature validation owns the raw bytes.
          safe_env = env.merge("rack.input" => StringIO.new(body), "CONTENT_LENGTH" => body.bytesize.to_s,
            "CONTENT_TYPE" => "application/octet-stream", "hrm.integration.webhook_json" => true)
          @app.call(safe_env)
        end
        private
        def error(code, message)
          [ code, { "content-type" => "application/json", "cache-control" => "no-store" }, [ JSON.generate(error: message) ] ]
        end
      end
    end
  end
end
