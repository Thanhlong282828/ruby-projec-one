class ApplicationPolicy
  attr_reader :user, :record
  def initialize(user, record)
    @user, @record = user, record
  end
  def index? = user&.staff?
  def show? = user&.staff?
  def create? = user&.staff?
  def new? = create?
  def update? = user&.staff?
  def edit? = update?
  def destroy? = user&.admin?
  class Scope
    attr_reader :user, :scope
    def initialize(user, scope)
      @user, @scope = user, scope
    end
    def resolve = user&.staff? ? scope.all : scope.none
  end
end
