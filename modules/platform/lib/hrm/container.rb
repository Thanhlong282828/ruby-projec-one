module Hrm
  # Small, explicit binding registry. Store names, not reloadable class instances.
  class Container
    class MissingBinding < StandardError; end
    class InvalidBinding < StandardError; end
    def initialize
      @bindings = {}
      @mutex = Mutex.new
    end
    def bind(contract, implementation:)
      key = contract.is_a?(String) ? contract : contract.name
      target = implementation.is_a?(String) ? implementation : implementation.name
      @mutex.synchronize { @bindings[key] = target }
    end
    def resolve(contract)
      key = contract.is_a?(String) ? contract : contract.name
      target = @mutex.synchronize { @bindings.fetch(key) { raise MissingBinding, "No provider registered for #{key}" } }
      instance = target.constantize.new
      raise InvalidBinding, "#{target} must implement #{key}" unless instance.is_a?(key.constantize)
      instance
    end
    def bindings = @mutex.synchronize { @bindings.dup.freeze }
    class << self
      def default = @default ||= new
      def bind(contract, implementation:) = default.bind(contract, implementation: implementation)
      def resolve(contract) = default.resolve(contract)
      def bindings = default.bindings
    end
  end
end
