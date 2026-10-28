class HrUpdatesChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_user.allowed?("realtime.read")
    company_id = current_user.company_id
    stream_from "company_#{company_id}_hr_updates", coder: ActiveSupport::JSON do |message|
      # Recheck active account/company and current grants for existing subscriptions too.
      if current_user.reload.company_id == company_id && current_user.allowed?("realtime.read")
        transmit(message)
      else
        stop_all_streams
      end
    rescue ActiveRecord::RecordNotFound
      stop_all_streams
    end
  end
end
