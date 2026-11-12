module HrmOrganization
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        def build(resource:, company_id:, attributes:)
          Domain::Resources.model(resource).new(attributes.except(:company_id, "company_id").merge(company_id: company_id))
        end
        # All organization writes serialize on the company, including moves/capacity changes.
        def within_company_lock(company_id:, &block) = ::Company.find(company_id).with_lock(&block)
        def save!(record:, attributes: nil)
          record.assign_attributes(attributes.except(:company_id, "company_id")) if attributes
          record.save!
          record
        end
        def destroy!(record:) = record.destroy!
      end
    end
  end
end
