module Hrm
  class UseCase
    protected
    def require_actor!(actor)
      raise Pundit::NotAuthorizedError unless actor&.active?
    end
    def authorize!(actor, record, query)
      require_actor!(actor)
      Pundit.authorize(actor, record, query)
    end
  end
end
