module HrmAttendance
  module Application
    module Queries
      class PeriodReport < Hrm::UseCase
        class InvalidPeriod < ArgumentError; end
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, from: nil, to: nil, page: 1)
          authorize!(actor, ::Attendance, :index?)
          first = parse_date(from, Date.current.beginning_of_month)
          last = parse_date(to, Date.current)
          raise InvalidPeriod, "Kỳ báo cáo phải từ 1 đến 93 ngày." unless (0..92).cover?((last - first).to_i)
          result = @repository.period(actor: actor, from: first, to: last, page: page)
          rows = result.fetch(:records).map do |record|
            seconds = record.checked_out_at && (record.checked_out_at - record.checked_in_at).to_i
            employee = record.employee
            { id: record.id, employee_name: employee.full_name,
              employee_path: Pundit.policy!(actor, employee).show? ? "/employees/#{employee.id}" : nil,
              work_date: record.work_date, checked_in_at: record.checked_in_at,
              checked_out_at: record.checked_out_at, elapsed_minutes: seconds && (seconds / 60),
              status: seconds.nil? ? "open" : (seconds > 16.hours ? "excessive" : "closed") }
          end
          { from: first, to: last, page: [ page.to_i, 1 ].max, rows: rows,
            summary: result.fetch(:summary).merge(elapsed_minutes: result.fetch(:summary).fetch(:elapsed_seconds) / 60) }
        end
        private
        def parse_date(value, fallback)
          return fallback if value.nil? || value == ""
          raise InvalidPeriod, "Ngày phải có dạng YYYY-MM-DD." unless value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value)
          Date.iso8601(value)
        rescue Date::Error
          raise InvalidPeriod, "Ngày không hợp lệ."
        end
      end
    end
  end
end
