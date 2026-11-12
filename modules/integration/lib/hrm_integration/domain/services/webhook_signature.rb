require "openssl"
module HrmIntegration
  module Domain
    module Services
      class WebhookSignature
        class Unauthorized < StandardError; end
        class InvalidPayload < StandardError; end
        class Conflict < StandardError; end
        MAX_BYTES = 65_536
        def self.verify!(secret:, timestamp:, event_id:, signature:, body:, now: Time.current.to_i)
          valid = timestamp.is_a?(String) && /\A[0-9]{10,12}\z/.match?(timestamp) && (now - timestamp.to_i).abs <= 300
          valid &&= event_id.is_a?(String) && /\A[A-Za-z0-9][A-Za-z0-9_.:-]{0,99}\z/.match?(event_id)
          valid &&= signature.is_a?(String) && /\A[0-9a-f]{64}\z/.match?(signature)
          raise Unauthorized unless valid && body.is_a?(String) && body.bytesize.between?(1, MAX_BYTES)
          expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{event_id}.#{body}")
          raise Unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
        end
        def self.parse!(body)
          text = body.dup.force_encoding(Encoding::UTF_8)
          raise InvalidPayload unless text.valid_encoding?
          data = JSON.parse(text, max_nesting: 32)
          valid = data.is_a?(Hash) && data.keys.sort == %w[event_type payload] && data["payload"].is_a?(Hash)
          valid &&= data["event_type"].is_a?(String) && /\A[a-z][a-z0-9_.-]{0,99}\z/.match?(data["event_type"])
          raise InvalidPayload unless valid
          data
        rescue JSON::ParserError
          raise InvalidPayload
        end
      end
    end
  end
end
