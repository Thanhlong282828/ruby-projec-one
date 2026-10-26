module HrmAudit
  class Engine < ::Rails::Engine
    engine_name "hrm_audit"
    config.root = File.expand_path("../..", __dir__)

    # Like Laravel's provider registration; re-run after Rails reloads classes.
    config.to_prepare do
      HrmAudit::Providers::AuditServiceProvider.new.register
      HrmAudit::Providers::EventServiceProvider.boot
    end

    # Shared schema and public constants preserve existing data and route helpers.
    # Code is owned by an engine, while the host composes the enabled modules.
    config.autoload_paths << root.join("lib")
    config.eager_load_paths << root.join("lib")

    initializer "hrm_audit.route_fragments" do |app|
      app.routes.draw_paths << root.join("config/routes").to_s
    end

    initializer "hrm_audit.migrations" do |app|
      app.config.paths["db/migrate"].concat(config.paths["db/migrate"].expanded)
    end
  end
end
