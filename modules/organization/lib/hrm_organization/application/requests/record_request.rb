module HrmOrganization
  module Application
    module Requests
      class RecordRequest
        def self.read(params, resource:)
          fields = Domain::Resources.fetch(resource).fetch(:fields).keys
          params.require(:record).permit(*fields).to_h.symbolize_keys
        end
      end
    end
  end
end
