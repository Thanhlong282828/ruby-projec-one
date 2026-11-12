module HrmIdentity
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def personal_sessions(actor:, credential:, before: nil)
          current = WebSessionAccess.check!(actor: actor, credential: credential)
          raise ActiveRecord::RecordNotFound unless before.nil? || (before.is_a?(String) && /\A[1-9][0-9]{0,17}\z/.match?(before))
          scope = ::LoginSession.unexpired.where(principal_user_id: current.principal_user_id)
          scope = scope.where(id: ...before.to_i) if before
          records = scope.order(id: :desc).limit(26).pluck(:id, :user_id, :created_at, :expires_at)
          more = records.length > 25
          records = records.first(25)
          profiles = ::User.where(id: records.pluck(1)).includes(:company).index_by(&:id)
          { next_before: more ? records.last[0] : nil, records: records.map do |id, user_id, created_at, expires_at|
            profile = profiles.fetch(user_id)
            { id: id, company_id: profile.company_id, company_name: profile.company.name,
             created_at: created_at, expires_at: expires_at, current: id == current.id }
          end }
        end
        def active_user(id:) = ::User.joins(:company).where(companies: { active: true }).find_by(id: id, active: true)
        def active_user_by_email(email:)
          principal = ::User.find_by(email: email.to_s.strip.downcase, principal_user_id: nil, active: true)
          return unless principal
          return principal if principal.enabled_for_access?
          principal.company_profiles.joins(:company).where(active: true, companies: { active: true }).order(:id).find { |profile| profile.enabled_for_access? }
        end
        def valid_login_session(raw:) = ::LoginSession.unexpired.includes(:user).find_by(digest: Digest::SHA256.hexdigest(raw.to_s))
        def valid_token(raw:) = ::ApiToken.valid_now.includes(:user).find_by(digest: Digest::SHA256.hexdigest(raw.to_s))
        def user_options(actor:)
          raise Pundit::NotAuthorizedError unless actor&.allowed?("employees.create") || actor&.allowed?("employees.update")
          ::User.where(company_id: actor.company_id).order(:email).to_a
        end
        def summary_recipients(company_id:) = ::User.where(company_id: company_id, active: true).to_a.select { |user| user.allowed?("leave.read_all") && user.allowed?("leave.review") }
      end
    end
  end
end
