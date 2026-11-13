class PurchaseRequestPolicy < ApplicationPolicy
  def index? = allowed?("procurement.requests.read") || allowed?("procurement.requests.read_all")
  def show? = index? && (allowed?("procurement.requests.read_all") || owner?)
  def create? = index? && allowed?("procurement.requests.create")
  def update_any? = index? && allowed?("procurement.requests.update")
  def submit_any? = index? && allowed?("procurement.requests.submit")
  def update_draft? = update_any? && owner?
  def submit_request? = submit_any? && owner?
  def update? = update_draft? && record.status == "draft"
  def submit? = submit_request? && record.status == "draft"
  def review_queue? = allowed?("procurement.requests.read_all") && allowed?("procurement.requests.review")
  def decide? = review_queue? && !record.is_a?(Class) && record.created_by_id != user.id
  def review? = decide? && record.status == "submitted"
  private
  def owner? = !record.is_a?(Class) && record.created_by_id == user.id
  class Scope < ApplicationPolicy::Scope
    def resolve
      return tenant if user&.allowed?("procurement.requests.read_all")
      user&.allowed?("procurement.requests.read") ? tenant.where(created_by_id: user.id) : scope.none
    end
  end
end
