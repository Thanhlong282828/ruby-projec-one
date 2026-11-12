module HrmIntegration
  module Domain
    module Services
      class PayrollNotification
        def self.body(descriptor) = { event_type: "payroll.export.ready", payload: descriptor }.to_json
        def self.verify!(actor:, record:, source_repository:)
          return OutboundEnvelope.verify!(body: record.payload, digest: record.body_digest) unless record.payroll_export_id
          source_repository.with_verified_descriptor(actor: actor, id: record.payroll_export_id) do |descriptor|
            bytes = record.payload
            expected = body(descriptor)
            valid = bytes.is_a?(String) && bytes.bytesize <= WebhookSignature::MAX_BYTES &&
              ActiveSupport::SecurityUtils.secure_compare(expected, bytes) &&
              ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(bytes), record.body_digest)
            raise WebhookSignature::InvalidPayload unless valid
            bytes
          end
        rescue HrmPayroll::Domain::Services::PayrollCsv::IntegrityError, ActiveRecord::Encryption::Errors::Decryption
          raise WebhookSignature::InvalidPayload
        end
      end
    end
  end
end
