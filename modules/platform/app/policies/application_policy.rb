class ApplicationPolicy
  attr_reader :user, :record
  def initialize(user, record) = (@user, @record = user, record)
  def index? = false
  def show? = false
  def create? = false
  def update? = false
  def destroy? = false
  def new? = create?
  def edit? = update?
  protected
  def allowed?(key) = user&.allowed?(key) && same_company?
  def same_company? = record.is_a?(Class) || (user && record.company_id == user.company_id)
  class Scope
    attr_reader :user, :scope
    def initialize(user, scope) = (@user, @scope = user, scope)
    def tenant = user&.active? && user.company&.active? ? scope.where(company_id: user.company_id) : scope.none
    def resolve = scope.none
  end
end
