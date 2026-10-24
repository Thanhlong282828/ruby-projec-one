# Run with: docker compose exec -T web bundle exec rails runner script/smoke.rb
abort "Smoke script is development-only" unless Rails.env.development?
admin = User.find_by!(email: "admin@hrm.local")
employee = Employee.find_by!(employee_code: "XV001")
Current.user = admin
request = employee.leave_requests.find_by(reason: "Development smoke check") || TimeOff::Submit.call(employee: employee, attributes: { starts_on: Date.new(2026, 12, 20), ends_on: Date.new(2026, 12, 21), reason: "Development smoke check" })
TimeOff::Review.call(request: request, reviewer: admin, decision: "approved") if request.pending?
OutboxDispatchJob.perform_later
DailySummaryJob.perform_later
puts "Queued development smoke workflow. Pending events: #{OutboxEvent.pending.count}"
