module HrmPlatform
  class Engine < ::Rails::Engine
    engine_name "hrm_platform"
    config.root = File.expand_path("../..", __dir__)

    config.after_initialize do |app|
      # MigrationContext also runs outside Rake (pending checks, console, deploys).
      ActiveRecord::Migrator.migrations_paths = app.config.paths["db/migrate"].expanded
    end

    # Shared schema and public constants preserve existing data and route helpers.
    # Code is owned by an engine, while the host composes the enabled modules.
    config.autoload_paths << root.join("lib")
    config.eager_load_paths << root.join("lib")

    initializer "hrm_platform.route_fragments" do |app|
      app.routes.draw_paths << root.join("config/routes").to_s
    end

    initializer "hrm_platform.schedules" do |app|
      app.config.x.hrm.schedule_files ||= []
      app.config.x.hrm.schedule_files << root.join("config/schedule.yml")
    end

    initializer "hrm_platform.migrations" do |app|
      app.config.paths["db/migrate"].concat(config.paths["db/migrate"].expanded)
    end
  end
end
