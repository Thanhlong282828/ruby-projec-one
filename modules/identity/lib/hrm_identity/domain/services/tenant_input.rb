module HrmIdentity
  module Domain
    module Services
      class TenantInput
        class Invalid < StandardError; end
        def self.id!(value)
          valid = (value.is_a?(Integer) && value.positive?) || (value.is_a?(String) && /\A[1-9][0-9]{0,18}\z/.match?(value))
          raise Invalid unless valid && value.to_i <= 9_223_372_036_854_775_807
          value.to_i
        end
        def self.attributes(input)
          raise Invalid unless input.is_a?(Hash)
          data = input.symbolize_keys
          raise Invalid unless data[:code].is_a?(String) && /\A[A-Z0-9_-]{1,30}\z/.match?(data[:code]) && data[:name].is_a?(String) && data[:name].strip.length.between?(1, 255)
          { code: data[:code], name: data[:name].strip }
        end
        def self.version!(value)
          raise Invalid unless (value.is_a?(Integer) && value >= 0) || (value.is_a?(String) && /\A[0-9]{1,10}\z/.match?(value))
          value.to_i
        end
      end
    end
  end
end
