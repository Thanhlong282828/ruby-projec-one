module HrmIdentity
  module Application
    module Requests
      class AdministrationRequest
        def self.read(params, area:)
          permitted = case area
          when :company then params.require(:company).permit(:name)
          when :accounts
            input = params.require(:account)
            # Role is a privileged, explicitly validated command input, never a
            # generic model mass-assignment field. The repository authorizes the
            # actor and resolves the requested role inside that actor's company.
            result = input.permit(:active, permission_overrides: {}).to_h.symbolize_keys
            result[:role] = input[:role].to_s if input.key?(:role)
            return result
          when :roles then params.require(:role).permit(:key, :name, permission_keys: [])
          end
          permitted.to_h.symbolize_keys
        end
      end
    end
  end
end
