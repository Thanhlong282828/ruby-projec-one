module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    def connect
      self.current_user = HrmIdentity::Application::Queries::FindActiveUser.new.call(id: request.session[:user_id]) || reject_unauthorized_connection
    end
  end
end
