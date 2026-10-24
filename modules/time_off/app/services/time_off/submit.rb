module TimeOff
  class Submit
    def self.call(employee:, attributes:)
      employee.with_lock { employee.leave_requests.create!(attributes) }
    end
  end
end
