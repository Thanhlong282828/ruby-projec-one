require "digest"
module HrmProcurement
  module Domain
    module Services
      class ReversalContent
        def self.read(attributes)
          raise RequestContent::Invalid, "Dữ liệu đảo phiếu không hợp lệ" unless attributes.is_a?(Hash)
          key = attributes[:idempotency_key]
          raise RequestContent::Invalid, "Khóa thao tác không hợp lệ" unless key.is_a?(String) && key.valid_encoding? && /\A[a-zA-Z0-9-]{16,64}\z/.match?(key)
          { idempotency_key: key, reason: RequestContent.text(attributes[:reason], "Lý do đảo", 2000) }
        end
        def self.digest(source_id, content)
          Digest::SHA256.hexdigest(JSON.generate([ source_id, content[:reason] ]))
        end
      end
    end
  end
end
