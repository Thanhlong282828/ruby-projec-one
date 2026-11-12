class PersonalSessionPolicy < ApplicationPolicy
  def index? = user&.enabled_for_access?
  def destroy? = index? && record.principal_user_id == user.identity_id
end
