class PayRunPolicy < ApplicationPolicy
  def index? = allowed?("payroll.read")
  def show? = allowed?("payroll.read")
  def create? = allowed?("payroll.create")
  def update? = allowed?("payroll.finalize")
  class Scope < Scope
    def resolve = user&.allowed?("payroll.read") ? tenant : scope.none
  end
end
