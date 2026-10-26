module HrmIdentity
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        def issue_token!(user:) = ::ApiToken.issue!(user)
        def revoke_token!(token:) = token.destroy!
        def create_user!(attributes:) = ::User.create!(attributes)
        def disable_user!(email:)
          ::User.transaction do
            user = ::User.find_by!(email: email.to_s.strip.downcase)
            user.update!(active: false)
            user.api_tokens.destroy_all
          end
        end
        def purge_expired_tokens = ::ApiToken.where("expires_at < ?", Time.current).delete_all
      end
    end
  end
end
