class LeaveMailer < ApplicationMailer
  default from: ENV.fetch("MAIL_FROM", "hrm@example.test")
  def decision(request)
    @request = request
    mail(to: request.employee.email, subject: "HRM: Leave request #{request.status}")
  end
  def summary(user, count)
    mail(to: user.email, subject: "HRM: Daily summary", body: "Pending leave requests: #{count}", content_type: "text/plain")
  end
end
