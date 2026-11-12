require "csv"
require "digest"
module HrmPayroll
  module Domain
    module Services
      class PayrollCsv
        class InvalidSource < StandardError; end
        class IntegrityError < StandardError; end
        AMOUNT_COLUMNS = %w[gross_amount deductions_amount net_amount].freeze
        MAX_ROWS = 2000
        MAX_BYTES = 1_048_576
        HEADERS = %w[export_uuid period employee_code gross_amount deductions_amount net_amount currency amount_scale].freeze
        UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
        RISKY_CELL = /\A[\s\u0000-\u001f\uFEFF]*[=+@-]|\A[\t\r\n]/
        def self.build(public_id:, period:, rows:)
          raise InvalidSource unless public_id.is_a?(String) && UUID.match?(public_id) && rows.is_a?(Array) && rows.size.between?(1, MAX_ROWS)
          bytes = "\uFEFF" + CSV.generate(headers: HEADERS, write_headers: true, row_sep: "\r\n") do |csv|
            rows.each do |row|
              gross, deductions, net = row.values_at(:gross_cents, :deductions_cents, :net_cents)
              raise InvalidSource unless valid_amounts?([ gross, deductions, net ])
              code = row[:employee_code]
              code = code.dup.force_encoding(Encoding::UTF_8) if code.is_a?(String)
              raise InvalidSource unless code.is_a?(String) && code.valid_encoding? && code.bytesize.between?(1, 100) && code.exclude?("\0")
              code = "'#{code}" if RISKY_CELL.match?(code)
              csv << [ public_id, period.iso8601, code, gross, deductions, net, "VND", 0 ]
            end
          end
          raise InvalidSource if bytes.bytesize > MAX_BYTES
          { bytes: bytes, checksum: Digest::SHA256.hexdigest(bytes), byte_size: bytes.bytesize, employee_count: rows.size }
        end
        def self.verify!(bytes:, checksum:, byte_size:, employee_count:, public_id:, period:)
          bytes = bytes.dup.force_encoding(Encoding::UTF_8) if bytes.is_a?(String)
          valid = bytes.is_a?(String) && bytes.valid_encoding? && bytes.bytesize.between?(1, MAX_BYTES) && bytes.bytesize == byte_size
          valid &&= checksum.is_a?(String) && /\A[0-9a-f]{64}\z/.match?(checksum) && ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(bytes), checksum)
          valid &&= public_id.is_a?(String) && UUID.match?(public_id) && bytes.start_with?("\uFEFF#{HEADERS.join(',')}\r\n")
          raise IntegrityError unless valid
          rows = CSV.parse(bytes.delete_prefix("\uFEFF"), headers: true)
          raise IntegrityError unless rows.headers == HEADERS && rows.size == employee_count && rows.size.between?(1, MAX_ROWS)
          valid_rows = rows.all? do |row|
            amounts = AMOUNT_COLUMNS.map { |key| row[key] }
            code = row["employee_code"]
            row.fields.size == HEADERS.size && row["export_uuid"] == public_id && row["period"] == period.iso8601 &&
              row["currency"] == "VND" && row["amount_scale"] == "0" && code.is_a?(String) && code.bytesize.between?(1, 101) &&
              code.exclude?("\0") && !RISKY_CELL.match?(code) && amounts.all? { |value| value.is_a?(String) && /\A[0-9]{1,19}\z/.match?(value) } &&
              valid_amounts?(amounts.map(&:to_i))
          end
          raise IntegrityError unless valid_rows
          bytes
        rescue CSV::MalformedCSVError, ArgumentError, TypeError
          raise IntegrityError
        end
        def self.valid_amounts?(values)
          values.all? { |value| value.is_a?(Integer) && value.between?(0, 9_223_372_036_854_775_807) } && values[2] == values[0] - values[1]
        end
        private_class_method :valid_amounts?
      end
    end
  end
end
