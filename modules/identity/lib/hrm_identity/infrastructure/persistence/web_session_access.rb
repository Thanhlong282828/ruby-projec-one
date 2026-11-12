module HrmIdentity
  module Infrastructure
    module Persistence
      module WebSessionAccess
        def self.check!(actor:, credential:)
          raise Pundit::NotAuthorizedError unless actor && credential.is_a?(::LoginSession) && credential.persisted?
          ActiveRecord::Base.uncached do
            profile = ::User.find_by(id: actor.id)
            raise Pundit::NotAuthorizedError unless profile&.enabled_for_access? && profile.identity_id == actor.identity_id
            current = ::LoginSession.unexpired.find_by(id: credential.id, user_id: profile.id, principal_user_id: profile.identity_id)
            raise Pundit::NotAuthorizedError unless current
            current
          end
        end
      end
    end
  end
end
