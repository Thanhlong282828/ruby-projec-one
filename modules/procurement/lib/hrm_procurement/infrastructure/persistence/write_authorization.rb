module HrmProcurement
  module Infrastructure
    module Persistence
      # Locking reads see current grants even inside an older REPEATABLE READ caller.
      # This short-lived context is only used while its IAM/company/grant locks are held.
      class WriteAuthorization
        Context = Data.define(:id, :company_id, :company, :permission_keys) do
          def allowed?(key) = permission_keys.include?(key)
          def active? = true
        end
        def self.lock!(actor)
          principal = ::User.where(id: actor.identity_id).lock.first!
          profile = ::User.where(id: actor.id, company_id: actor.company_id).lock.first!
          company = ::Company.where(id: profile.company_id).lock.first!
          valid_identity = profile.id == principal.id || profile.principal_user_id == principal.id
          raise Pundit::NotAuthorizedError unless principal.active? && principal.principal_user_id.nil? && profile.active? && company.active? && valid_identity
          role = ::CompanyRole.where(company_id: profile.company_id, key: profile.role).lock.first!
          inherited = ::Permission.joins(:role_permissions).where(role_permissions: { company_role_id: role.id }).lock.pluck(:key)
          overrides = ::UserPermission.where(user_id: profile.id).joins(:permission).lock.pluck("permissions.key", :granted)
          keys = (inherited + overrides.select { |_, granted| granted }.map(&:first)).uniq - overrides.reject { |_, granted| granted }.map(&:first)
          Context.new(id: profile.id, company_id: profile.company_id, company: company, permission_keys: keys.freeze)
        end
      end
    end
  end
end
