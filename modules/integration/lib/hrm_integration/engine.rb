require_relative "infrastructure/http/webhook_body_limit"
module HrmIntegration
  class Engine < ::Rails::Engine
    engine_name "hrm_integration"
    config.root = File.expand_path("../..", __dir__)

    # Like Laravel's provider registration; re-run after Rails reloads classes.
    config.to_prepare do
      HrmIntegration::Providers::IntegrationServiceProvider.new.register
    end

    # Shared schema and public constants preserve existing data and route helpers.
    # Code is owned by an engine, while the host composes the enabled modules.
    config.autoload_paths << root.join("lib")
    config.eager_load_paths << root.join("lib")

    initializer "hrm_integration.webhook_body_limit" do |app|
      app.config.middleware.insert_after Rack::Attack, HrmIntegration::Infrastructure::Http::WebhookBodyLimit
    end

    initializer "hrm_integration.route_fragments" do |app|
      app.routes.draw_paths << root.join("config/routes").to_s
    end

    initializer "hrm_integration.schedules" do |app|
      app.config.x.hrm.schedule_files ||= []
      app.config.x.hrm.schedule_files << root.join("config/schedule.yml")
    end

    initializer "hrm_integration.migrations" do |app|
      app.config.paths["db/migrate"].concat(config.paths["db/migrate"].expanded)
    end
  end
end
