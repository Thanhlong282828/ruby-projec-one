class HrUpdatesChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user.staff?
    stream_from "hr_updates" if current_user.staff?
  end
end
