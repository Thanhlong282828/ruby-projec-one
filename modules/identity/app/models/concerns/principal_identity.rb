# typed: strict

# Rails mixes this concern into User; bind the host type rather than bypass typing.
module PrincipalIdentity
  extend T::Sig

  sig { returns(User) }
  def identity_user
    T.bind(self, User)
    principal_user || self
  end

  sig { returns(T.nilable(Integer)) }
  def identity_id
    T.bind(self, User)
    principal_user_id || id
  end
end
