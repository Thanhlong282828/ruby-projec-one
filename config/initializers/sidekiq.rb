Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL") }
  config.on(:startup) do
    Sidekiq::Cron::Job.load_from_hash({
      "outbox" => { "cron" => "* * * * *", "class" => "OutboxDispatchJob", "active_job" => true },
      "daily_hr_summary" => { "cron" => "0 8 * * * Asia/Ho_Chi_Minh", "class" => "DailySummaryJob", "active_job" => true }
    })
  end
end
Sidekiq.configure_client { |config| config.redis = { url: ENV.fetch("REDIS_URL") } }
