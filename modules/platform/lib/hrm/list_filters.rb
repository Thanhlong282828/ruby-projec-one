# typed: true

module Hrm
  # Only allow declared source filters. Company scope is never a request filter.
  module ListFilters
    extend T::Sig
    sig { params(value: Object, allowed: T::Array[String]).returns(T.nilable(String)) }
    def self.choice(value, allowed:)
      return nil if value.nil? || value == ""
      raise ActiveRecord::RecordNotFound unless value.is_a?(String) && allowed.include?(value)
      value
    end
    sig { params(value: Object).returns(T.nilable(Date)) }
    def self.month(value)
      return nil if value.nil? || value == ""
      raise ActiveRecord::RecordNotFound unless value.is_a?(String) && /\A\d{4}-(0[1-9]|1[0-2])\z/.match?(value)
      Date.iso8601("#{value}-01")
    rescue Date::Error
      raise ActiveRecord::RecordNotFound
    end
  end
end
