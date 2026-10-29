module Hrm
  class UseCase
    protected
    def require_actor!(actor)
      raise Pundit::NotAuthorizedError unless actor&.enabled_for_access?
    end
    def authorize!(actor, record, query)
      require_actor!(actor)
      Pundit.authorize(actor, record, query)
    end
  end
end
