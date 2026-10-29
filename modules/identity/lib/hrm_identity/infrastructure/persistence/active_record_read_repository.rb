module HrmIdentity
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def active_user(id:) = ::User.joins(:company).where(companies: { active: true }).find_by(id: id, active: true)
        def active_user_by_email(email:) = ::User.joins(:company).where(companies: { active: true }).find_by(email: email.to_s.strip.downcase, active: true)
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
