module HrmProcurement
  module Domain
    module Services
      class OrderContent
        def self.supplier(attributes)
          code = RequestContent.text(attributes[:code], "Mã nhà cung cấp", 40).upcase
          raise RequestContent::Invalid, "Mã chỉ gồm chữ, số, dấu _ và -" unless /\A[A-Z0-9][A-Z0-9_-]*\z/.match?(code)
          status = attributes[:status]
          raise RequestContent::Invalid, "Trạng thái nhà cung cấp không hợp lệ" unless %w[active inactive].include?(status)
          { code: code, name: RequestContent.text(attributes[:name], "Tên nhà cung cấp", 200), status: status }
        end
        def self.date(value)
          raise RequestContent::Invalid, "Ngày giao phải có dạng YYYY-MM-DD" unless value.is_a?(String) && /\A[1-9]\d{3}-\d{2}-\d{2}\z/.match?(value)
          Date.iso8601(value)
        rescue Date::Error
          raise RequestContent::Invalid, "Ngày giao không hợp lệ"
        end
        def self.prices(value, lines)
          value = value.values if value.is_a?(Hash) && value.keys.all? { |key| /\A\d{1,4}\z/.match?(key.to_s) }
          raise RequestContent::Invalid, "Phải gửi đúng các dòng nguồn" unless value.is_a?(Array) && value.size == lines.size && value.all?(Hash)
          rows = value.map(&:stringify_keys)
          ids = rows.map { |row| row["source_line_id"].to_s }
          raise RequestContent::Invalid, "Dòng nguồn bị thiếu, lặp hoặc không hợp lệ" unless ids.uniq.size == lines.size && ids.sort == lines.map { |line| line.source_line_id.to_s }.sort
          rows.to_h do |row|
            price = RequestContent.decimal(row["unit_price"], /\A(?:0|[1-9]\d{0,11})\z/, "Đơn giá VND phải nguyên đồng, tối đa 12 chữ số")
            [ row["source_line_id"].to_s, price ]
          end
        end
        def self.reason(value)
          return nil if value.nil? || value == ""
          RequestContent.text(value, "Lý do thay đổi giá", 2000)
        end
      end
    end
  end
end
