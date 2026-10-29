module HrmIdentity
  module Infrastructure
    module Persistence
      class ActiveRecordAdministrationRepository < Domain::Repositories::AdministrationRepositoryInterface
        def snapshot(actor:, area:, id: nil)
          guard!(actor, { company: "company.manage", accounts: "accounts.manage", roles: "roles.manage" }.fetch(area))
          company = ::Company.find(actor.company_id)
          data = { company: company, permissions: ::Permission.order(:key).to_a }
          case area
          when :accounts
            data[:accounts] = ::User.where(company_id: company.id).order(:email).to_a
            data[:roles] = company.company_roles.order(:key).to_a
            if id
              account = ::User.where(company_id: company.id).find(id)
              data[:account] = account
              data[:overrides] = account.user_permissions.joins(:permission).pluck("permissions.key", :granted).to_h
              data[:effective] = account.effective_permission_keys
            end
          when :roles
            data[:roles] = company.company_roles.includes(:permissions).order(:key).to_a
          end
          data
        end
        def update_company!(actor:, attributes:)
          guard!(actor, "company.manage")
          actor.company.with_lock do
            guard!(actor, "company.manage")
            actor.company.update!(name: attributes.fetch(:name))
            audit!(actor, actor.company, "company.updated", ["name"])
          end
        end
        def update_account!(actor:, id:, attributes:)
          guard!(actor, "accounts.manage")
          actor.company.with_lock do
            guard!(actor, "accounts.manage")
            account = ::User.where(company_id: actor.company_id).lock.find(id)
            raise Domain::InvalidAdministration, "Không được tự thay đổi vai trò/quyền hoặc khóa tài khoản đang dùng." if account.id == actor.id
            role = attributes.fetch(:role, account.role).to_s.strip.downcase
            raise Domain::InvalidAdministration, "Vai trò không hợp lệ." unless ::CompanyRole.exists?(company_id: actor.company_id, key: role)
            active = attributes.key?(:active) ? ActiveModel::Type::Boolean.new.cast(attributes[:active]) : account.active?
            previous = account.user_permissions.joins(:permission).pluck("permissions.key", :granted).to_h.transform_values { |value| value ? "grant" : "deny" }
            overrides = attributes.fetch(:permission_overrides, previous).to_h.transform_keys(&:to_s).reject { |_, value| value.blank? || value == "inherit" }
            invalid_keys = overrides.keys - ::Permission.pluck(:key)
            raise Domain::InvalidAdministration, "Permission không tồn tại." if invalid_keys.any? || overrides.values.any? { |v| !%w[grant deny].include?(v) }
            if role == "admin" && Domain::PermissionCatalog::PROTECTED.any? { |key| overrides[key] == "deny" }
              raise Domain::InvalidAdministration, "Không được chặn các quyền quản trị cốt lõi của admin."
            end
            if account.admin? && account.active? && (role != "admin" || !active) && ::User.where(company_id: actor.company_id, role: "admin", active: true).count <= 1
              raise Domain::InvalidAdministration, "Company phải còn ít nhất một admin đang hoạt động."
            end
            account.update!(role: role, active: active)
            account.user_permissions.destroy_all
            overrides.each do |key, value|
              account.user_permissions.create!(permission: ::Permission.find_by!(key: key), granted: value == "grant")
            end
            account.api_tokens.destroy_all unless active
            audit!(actor, account, "account.access.updated", ["role", "active", "permission_overrides"])
            account
          end
        end
        def update_role!(actor:, id:, attributes:)
          guard!(actor, "roles.manage")
          actor.company.with_lock do
            guard!(actor, "roles.manage")
            role = id.present? ? ::CompanyRole.where(company_id: actor.company_id).lock.find(id) : actor.company.company_roles.new(key: attributes[:key])
            keys = Array(attributes.fetch(:permission_keys) { role.permissions.pluck(:key) }).reject(&:blank?).map(&:to_s).uniq
            raise Domain::InvalidAdministration, "Permission không tồn tại." if (keys - ::Permission.pluck(:key)).any?
            if role.key == "admin" && (Domain::PermissionCatalog::PROTECTED - keys).any?
              raise Domain::InvalidAdministration, "Admin phải giữ quyền đăng nhập tổng quan và quản trị company/tài khoản/quyền."
            end
            role.update!(name: attributes.fetch(:name, role.name))
            role.permissions = ::Permission.where(key: keys)
            audit!(actor, role, "role.permissions.updated", keys)
            role
          end
        end
        # Trusted local CLI provisioning. Never exposed as a public HTTP action.
        def create_company!(code:, name:, owner_email:, password:)
          ::Company.transaction do
            company = ::Company.create!(code: code, name: name)
            ::User.create!(company: company, email: owner_email, password: password, role: :admin)
            company
          end
        end
        def company_id_for_code!(code:) = ::Company.find_by!(code: code).id
        def active_companies = ::Company.where(active: true).order(:id).to_a
        private
        def guard!(actor, permission)
          raise Pundit::NotAuthorizedError unless actor&.allowed?(permission)
        end
        def audit!(actor, record, action, fields)
          ::AuditLog.create!(company_id: actor.company_id, actor: actor, record_type: record.class.name, record_id: record.id, action: action, metadata: { changed_fields: fields })
        end
      end
    end
  end
end
