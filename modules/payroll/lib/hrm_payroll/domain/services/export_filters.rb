module HrmPayroll
  module Domain
    module Services
      class ExportFilters
        class Invalid < StandardError; end
        def self.id!(value)
          valid = (value.is_a?(Integer) && value.positive?) || (value.is_a?(String) && /\A[1-9][0-9]{0,18}\z/.match?(value))
          raise Invalid unless valid && value.to_i <= 9_223_372_036_854_775_807
          value.to_i
        end
        def self.period!(value)
          return nil if value.nil? || value == ""
          raise Invalid unless value.is_a?(String) && /\A[0-9]{4}-(0[1-9]|1[0-2])\z/.match?(value)
          Date.iso8601("#{value}-01")
        rescue Date::Error
          raise Invalid
        end
      end
    end
  end
end
