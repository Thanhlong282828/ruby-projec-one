module Hrm
  # Equivalent responsibility to a Laravel ServiceProvider#register.
  class ServiceProvider
    def initialize(container: Hrm::Container)
      @container = container
    end
    def register = raise(NotImplementedError)
    protected
    def bind(contract, implementation) = @container.bind(contract, implementation: implementation)
  end
end
