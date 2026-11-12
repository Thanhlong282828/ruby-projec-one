module HrmIntegration
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        def create!(actor:, attributes:)
          record = ::IntegrationConnection.new(company_id: actor.company_id,
            code: attributes[:code], name: attributes[:name], public_id: SecureRandom.uuid,
            signing_secret: SecureRandom.hex(32), active: false)
          Pundit.authorize(actor, record, :create?)
          Current.set(user: actor) { record.save! }
          { record: record, secret: record.signing_secret }
        end
        def change_status!(actor:, id:, active:, lock_version:)
          record = read.connection!(actor: actor, id: id)
          mutate(record, actor, lock_version) do
            invalid!(record, "Trạng thái kết nối không hợp lệ") unless [ true, false, "true", "false" ].include?(active)
            record.active = active == true || active == "true"
          end
        end
        def rotate!(actor:, id:, lock_version:)
          record = read.connection!(actor: actor, id: id)
          mutate(record, actor, lock_version) { record.signing_secret = SecureRandom.hex(32) }
          { record: record, secret: record.signing_secret }
        end
        def review!(actor:, id:, decision:, note:, lock_version:)
          record = read.webhook!(actor: actor, id: id)
          mutate(record, actor, lock_version) do
            invalid!(record, "Sự kiện đã được xử lý") unless record.status == "received"
            invalid!(record, "Quyết định không hợp lệ") unless %w[acknowledged rejected].include?(decision)
            invalid!(record, "Ghi chú phải là văn bản tối đa 1000 ký tự") unless note.nil? || (note.is_a?(String) && note.length <= 1000)
            record.assign_attributes(status: decision, review_note: note, reviewed_at: Time.current)
          end
        end
        private
        def read = ActiveRecordReadRepository.new
        def mutate(record, actor, version)
          record.with_lock do
            Pundit.authorize(actor, record, :update?)
            valid = (version.is_a?(Integer) && version >= 0) || (version.is_a?(String) && /\A[0-9]{1,10}\z/.match?(version))
            raise ActiveRecord::StaleObjectError.new(record, "update") unless valid && version.to_i == record.lock_version
            yield
            Current.set(user: actor) { record.save! }
            record
          end
        end
        def invalid!(record, message)
          record.errors.add(:base, message)
          raise ActiveRecord::RecordInvalid, record
        end
      end
    end
  end
end
