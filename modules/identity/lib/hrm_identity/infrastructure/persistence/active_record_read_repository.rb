module HrmIdentity
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def active_user(id:) = ::User.find_by(id: id, active: true)
        def active_user_by_email(email:) = ::User.find_by(email: email.to_s.strip.downcase, active: true)
        def valid_token(raw:) = ::ApiToken.valid_now.includes(:user).find_by(digest: Digest::SHA256.hexdigest(raw.to_s))
        def user_options(actor:)
          raise Pundit::NotAuthorizedError unless actor&.active? && actor.staff?
          ::User.order(:email).to_a
        end
        def summary_recipients = ::User.where(active: true, role: %w[admin hr]).to_a
      end
    end
  end
end
