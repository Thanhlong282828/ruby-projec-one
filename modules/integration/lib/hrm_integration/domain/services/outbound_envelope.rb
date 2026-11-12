module HrmIntegration
  module Domain
    module Services
      # Generic outbound messages cannot claim a server-owned business source.
      # Future typed bridges must verify their own source and use a separate contract.
      class OutboundEnvelope
        RESERVED_ROOTS = %w[payroll erp government].freeze

        def self.verify!(body:, digest: nil)
          invalid! unless body.is_a?(String) && body.bytesize.between?(1, WebhookSignature::MAX_BYTES)
          data = WebhookSignature.parse!(body)
          invalid! if RESERVED_ROOTS.include?(data.fetch("event_type").split(".").first)
          unless digest.nil?
            invalid! unless digest.is_a?(String) && /\A[0-9a-f]{64}\z/.match?(digest)
            invalid! unless ActiveSupport::SecurityUtils.secure_compare(digest, Digest::SHA256.hexdigest(body))
          end
          body.dup.force_encoding(Encoding::UTF_8)
        end

        def self.invalid! = raise(WebhookSignature::InvalidPayload)
        private_class_method :invalid!
      end
    end
  end
end
