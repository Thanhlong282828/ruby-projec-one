module HrmIdentity
  module Infrastructure
    module Persistence
      class ActiveRecordTenantWriteRepository < Domain::Repositories::TenantWriteRepositoryInterface
        def grant_system_owner!(email:)
          raise Domain::Services::TenantInput::Invalid unless email.is_a?(String)
          principal = ::User.where(principal_user_id: nil, active: true).find_by!(email: email.strip.downcase)
          principal.with_lock do
            ::SystemGrant::KEYS.each do |key|
              ::SystemGrant.find_or_create_by!(user: principal, permission: ::Permission.find_by!(key: key))
            end
            evidence!(principal, principal.company, "system.owner.provisioned", principal)
            principal
          end
        end
        def create_company!(actor:, attributes:)
          guard!(actor)
          data = Domain::Services::TenantInput.attributes(attributes)
          actor.identity_user.with_lock do
            ::SystemGrant.where(user_id: actor.identity_id).lock.load
            guard!(actor)
            company = ::Company.create!(data)
            profile = ::User.create!(principal_user_id: actor.identity_id, company: company, email: actor.identity_user.email, role: "admin")
            evidence!(actor, company, "system.company.created", company)
            evidence!(actor, company, "system.membership.created", profile)
            company
          end
        end
        def update_company!(actor:, id:, attributes:, lock_version:)
          guard!(actor)
          company = ::Company.find(Domain::Services::TenantInput.id!(id))
          company.with_lock do
            guard!(actor)
            raise ActiveRecord::StaleObjectError.new(company, "update") unless company.lock_version == Domain::Services::TenantInput.version!(lock_version)
            raise Domain::Services::TenantInput::Invalid unless attributes.is_a?(Hash) && attributes[:name].is_a?(String) && attributes[:name].strip.length.between?(1, 255)
            active = attributes[:active]
            raise Domain::Services::TenantInput::Invalid unless [ true, false, "true", "false", "1", "0" ].include?(active)
            active = [ true, "true", "1" ].include?(active)
            raise Domain::Services::TenantInput::Invalid if !active && company.id == actor.company_id
            company.update!(name: attributes[:name].strip, active: active)
            evidence!(actor, company, "system.company.updated", company)
            company
          end
        end
        def assign_membership!(actor:, company_id:, principal_id:, role:)
          guard!(actor)
          principal = ::User.where(principal_user_id: nil).find(Domain::Services::TenantInput.id!(principal_id))
          company = ::Company.find(Domain::Services::TenantInput.id!(company_id))
          principal.with_lock do
            company.with_lock do
              guard!(actor)
              raise Domain::Services::TenantInput::Invalid unless principal.active? && company.active? && role.is_a?(String) && company.company_roles.exists?(key: role)
              raise Domain::Services::TenantInput::Invalid if principal.company_id == company.id
              existing = ::User.find_by(principal_user_id: principal.id, company_id: company.id)
              return existing if existing && existing.role == role && existing.active?
              raise Domain::Services::TenantInput::Invalid if existing
              profile = ::User.create!(company: company, principal_user: principal, email: principal.email, role: role)
              evidence!(actor, company, "system.membership.created", profile)
              profile
            end
          end
        end
        def switch!(actor:, credential:, membership_id:)
          raise Pundit::NotAuthorizedError unless credential.is_a?(::LoginSession) || credential.is_a?(::ApiToken)
          raise ActiveRecord::RecordNotFound unless credential.persisted?
          principal = ::User.where(principal_user_id: nil).find(credential.principal_user_id)
          principal.with_lock do
            scope = ::User.where(id: principal.id).or(::User.where(principal_user_id: principal.id))
            target = scope.lock.find(Domain::Services::TenantInput.id!(membership_id))
            credential.with_lock do
              valid = ActiveRecord::Base.uncached { actor&.enabled_for_access? && actor.id == credential.user_id && actor.identity_id == principal.id && credential.expires_at > Time.current && credential.principal_user_id == principal.id && principal.active? && target.enabled_for_access? }
              raise Pundit::NotAuthorizedError unless valid
              credential.update!(user: target)
              # Keep the original absolute expiry: switching cannot extend a login.
              ::AuditLog.create!(company_id: target.company_id, actor: target, action: "company.context.selected", record_type: "User", record_id: target.id, metadata: { changed_fields: [ "company_context" ] })
              Hrm::Container.resolve(HrmPlatform::Domain::Repositories::OutboxRepositoryInterface).append!(company_id: target.company_id, event_type: "company_context.selected", payload: { record_id: target.id, record_type: "User" })
              target
            end
          end
        end
        private
        def guard!(actor)
          ActiveRecord::Base.uncached { Pundit.authorize(actor, ::Company, :create?, policy_class: ::SystemCompanyPolicy) }
        end
        def evidence!(actor, company, action, record)
          ::SystemAuditLog.create!(principal_user_id: actor.identity_id, company: company, action: action, record_type: record.class.name, record_id: record.id)
          Hrm::Container.resolve(HrmPlatform::Domain::Repositories::OutboxRepositoryInterface).append!(company_id: company.id, event_type: action, payload: { record_id: record.id, record_type: record.class.name })
        end
      end
    end
  end
end
