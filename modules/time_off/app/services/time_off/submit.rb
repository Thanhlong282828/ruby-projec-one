module TimeOff
  class Submit
    def self.call(employee:, attributes:)
      # Legacy trusted caller (seeds/tests); HTTP uses SubmitLeave with actor checks.
      Hrm::Container.resolve(HrmTimeOff::Domain::Repositories::WriteRepositoryInterface).create!(employee: employee, attributes: attributes)
    end
  end
end
