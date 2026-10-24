namespace :hrm do
  desc "Retry pending outbox deliveries"
  task dispatch_events: :environment do
    OutboxDispatchJob.perform_later
  end
end
