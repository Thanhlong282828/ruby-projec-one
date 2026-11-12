module Hrm
  # Engines register event prefixes and permission names; no reloadable classes are retained.
  class RealtimeAuthorization
    def self.allowed?(actor:, message:)
      return false unless actor&.allowed?("realtime.read") && message.is_a?(Hash)
      type = message["type"] || message[:type]
      return false unless type.is_a?(String)
      registry = Rails.application.config.x.hrm.realtime_permissions || {}
      matches = registry.select { |prefix, _| type.start_with?(prefix) }.values
      valid = matches.all? do |value|
        names = value.is_a?(Array) ? value : [ value ]
        names.any? && names.all? { |name| name.is_a?(String) && name.present? }
      end
      return false unless valid
      return false unless matches.flat_map { |value| value.is_a?(Array) ? value : [ value ] }.uniq.all? { |permission| actor.allowed?(permission) }
      guards = Rails.application.config.x.hrm.realtime_guards || {}
      guards.select { |prefix, _| type.start_with?(prefix) }.values.all? do |name|
        guard = name.is_a?(String) && name.present? ? name.safe_constantize : nil
        guard && guard.respond_to?(:allowed?) && guard.allowed?(actor: actor, message: message)
      end
    end
  end
end
