module HrmPlatform
  module Infrastructure
    module Persistence
      class ActiveRecordOutboxRepository < Domain::Repositories::OutboxRepositoryInterface
        def append!(event_type:, payload:) = ::OutboxEvent.create!(event_type: event_type, payload: payload)
        def pending(limit: 100) = ::OutboxEvent.pending.order(:id).limit(limit).to_a
        def deliver(event:)
          event.with_lock do
            return if event.delivered_at
            yield
            event.update!(delivered_at: Time.current)
          end
        end
      end
    end
  end
end
