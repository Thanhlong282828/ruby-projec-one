# typed: strict

module HrmIdentity
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        extend T::Sig
        sig { override.params(actor: User, credential: Object, id: Object).returns(T.nilable(AuditLog)) }
        def revoke_personal_session!(actor:, credential:, id:)
          WebSessionAccess.check!(actor: actor, credential: credential)
          raise ActiveRecord::RecordNotFound unless id.is_a?(String) && /\A[1-9][0-9]{0,17}\z/.match?(id)
          actor.identity_user.with_lock do
            actor.with_lock do
              current = WebSessionAccess.check!(actor: actor, credential: credential)
              current.lock!
              # A context switch or revocation while waiting cannot authorize this command.
              WebSessionAccess.check!(actor: actor, credential: current)
              target = ::LoginSession.unexpired.where(principal_user_id: current.principal_user_id).lock.find(id)
              Pundit.authorize(actor, target, :destroy?, policy_class: ::PersonalSessionPolicy)
              raise Pundit::NotAuthorizedError if target.id == current.id
              target.destroy!
              ::AuditLog.create!(company_id: actor.company_id, actor: actor, action: "security.web_session.revoked", record_type: "LoginSession", record_id: target.id, metadata: { changed_fields: [ "revoked" ] })
            end
          end
        end
        sig { override.params(user: User).returns(T.nilable(String)) }
        def issue_login_session!(user:)
          principal = user.identity_user
          expected_digest = principal.password_digest
          principal.with_lock do
            user.with_lock do
              valid = ActiveRecord::Base.uncached { user.enabled_for_access? && principal.active? && principal.password_digest == expected_digest }
              raise Pundit::NotAuthorizedError unless valid
              ::LoginSession.issue!(user)
            end
          end
        end
        sig { override.params(raw: Object).returns(Integer) }
        def revoke_login_session!(raw:) = ::LoginSession.where(digest: Digest::SHA256.hexdigest(raw.to_s)).delete_all
        sig { override.params(user: User).returns(T.nilable(String)) }
        def issue_token!(user:)
          principal = user.identity_user
          expected_digest = principal.password_digest
          principal.with_lock do
            user.with_lock do
              valid = ActiveRecord::Base.uncached { user.enabled_for_access? && principal.active? && principal.password_digest == expected_digest }
              raise Pundit::NotAuthorizedError unless valid
              ::ApiToken.issue!(user)
            end
          end
        end
        sig { override.params(token: ApiToken).returns(ApiToken) }
        def revoke_token!(token:) = token.destroy!
        sig { override.params(attributes: T::Hash[Symbol, Object]).returns(User) }
        def create_user!(attributes:) = ::User.create!(attributes)
        sig { override.params(email: Object).returns(T.nilable(T::Array[ApiToken])) }
        def disable_user!(email:)
          ::User.transaction do
            user = ::User.find_by!(email: email.to_s.strip.downcase, principal_user_id: nil)
            user.update!(active: false)
            user.api_tokens.destroy_all
          end
        end
        sig { override.returns(Integer) }
        def purge_expired_tokens
          removed_sessions = ::LoginSession.where(expires_at: ..Time.current).delete_all
          removed_sessions + ::ApiToken.where(expires_at: ..Time.current).delete_all
        end
      end
    end
  end
end
