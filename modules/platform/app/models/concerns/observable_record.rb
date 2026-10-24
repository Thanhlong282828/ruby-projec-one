module ObservableRecord
  extend ActiveSupport::Concern
  included do
    after_create { Hrm::RecordObserver.record(self, "created") }
    after_update { Hrm::RecordObserver.record(self, "updated") }
    after_destroy { Hrm::RecordObserver.record(self, "deleted") }
    after_commit { Hrm::RecordObserver.committed(self) }
  end
end
