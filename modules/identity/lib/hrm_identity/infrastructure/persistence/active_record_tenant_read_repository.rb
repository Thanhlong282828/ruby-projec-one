module HrmIdentity
  module Infrastructure
    module Persistence
      class ActiveRecordTenantReadRepository < Domain::Repositories::TenantReadRepositoryInterface
        def memberships(actor:)
          raise Pundit::NotAuthorizedError unless actor&.enabled_for_access?
          ::User.joins(:company).where(active: true, companies: { active: true })
            .where(id: actor.identity_id).or(::User.joins(:company).where(active: true, companies: { active: true }, principal_user_id: actor.identity_id))
            .includes(:company).order(:company_id).map { |u| { id: u.id, company_id: u.company_id, company_name: u.company.name, company_code: u.company.code, role: u.role, selected: u.id == actor.id } }
        end
        def companies(actor:, before: nil)
          Pundit.authorize(actor, ::Company, :index?, policy_class: ::SystemCompanyPolicy)
          scope = ::Company.all
          scope = scope.where(id: ...Domain::Services::TenantInput.id!(before)) unless before.nil? || before == ""
          rows = scope.order(id: :desc).limit(26).to_a
          ids = rows.first(25).map(&:id)
          counts = ::OrganizationUnit.where(company_id: ids, unit_type: "branch").group(:company_id).count
          { companies: rows.first(25), branches: counts, total: ::Company.count, next_before: rows.size > 25 ? rows[24].id : nil }
        end
        def company(actor:, id:)
          Pundit.authorize(actor, ::Company, :index?, policy_class: ::SystemCompanyPolicy)
          record = ::Company.find(Domain::Services::TenantInput.id!(id))
          { company: record, roles: record.company_roles.order(:key).pluck(:name, :key),
           memberships: ::User.where(company_id: record.id).order(:id).limit(100).pluck(:id, :email, :role, :active, :principal_user_id),
           branches: ::OrganizationUnit.where(company_id: record.id, unit_type: "branch").order(:code).limit(100).pluck(:id, :code, :name),
           audits: ::SystemAuditLog.where(company_id: record.id).order(id: :desc).limit(25).to_a }
        end
      end
    end
  end
end
