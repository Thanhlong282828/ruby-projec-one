require "yaml"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL") }
  config.on(:startup) do
    schedules = Array(Rails.application.config.x.hrm.schedule_files).each_with_object({}) do |path, result|
      YAML.safe_load_file(path).each do |name, attributes|
        raise "Duplicate scheduled job: #{name}" if result.key?(name)
        result[name] = attributes
      end
    end
    Sidekiq::Cron::Job.load_from_hash(schedules)
  end
end

Sidekiq.configure_client { |config| config.redis = { url: ENV.fetch("REDIS_URL") } }
