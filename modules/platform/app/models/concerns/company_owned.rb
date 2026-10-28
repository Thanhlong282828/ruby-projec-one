module CompanyOwned
  extend ActiveSupport::Concern
  included do
    belongs_to :company
    scope :for_company, ->(company_id) { where(company_id: company_id) }
    validate do
      errors.add(:company_id, "cannot be moved to another company") if persisted? && will_save_change_to_company_id?
    end
  end
  private
  def same_company_as(*links)
    links.each do |link|
      target = public_send(link)
      errors.add(link, "must belong to the same company") if target && target.company_id != company_id
    end
  end
end
