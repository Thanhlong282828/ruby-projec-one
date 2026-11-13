require "bigdecimal"

module HrmProcurement
  module Domain
    module Services
      class RequestContent
        class Invalid < StandardError; end
        MAX_TOTAL = BigDecimal("999999999999999999")
        def self.read(attributes)
          title = text(attributes[:title], "Tiêu đề", 200)
          purpose = text(attributes[:purpose], "Mục đích mua", 4000)
          raw_date = attributes[:needed_on]
          raise Invalid, "Ngày cần hàng phải có dạng YYYY-MM-DD" unless raw_date.is_a?(String) && /\A[1-9]\d{3}-\d{2}-\d{2}\z/.match?(raw_date)
          needed_on = Date.iso8601(raw_date)
          items = rows(attributes[:items]).reject { |row| row.values.all?(&:blank?) }.map do |row|
            quantity = decimal(row["quantity"], /\A(?:0|[1-9]\d{0,5})(?:\.\d{1,3})?\z/, "Số lượng phải dương, tối đa 3 số lẻ")
            raise Invalid, "Số lượng phải lớn hơn 0" unless quantity.positive?
            price = decimal(row["estimated_unit_price"], /\A(?:0|[1-9]\d{0,11})\z/, "Đơn giá VND phải là số nguyên không âm, tối đa 12 chữ số")
            { description: text(row["description"], "Mô tả hàng", 500), unit: text(row["unit"], "Đơn vị", 30),
              quantity: quantity, estimated_unit_price: price,
              line_total: (quantity * price).round(0, BigDecimal::ROUND_HALF_UP) }
          end
          raise Invalid, "Cần từ 1 đến 50 dòng hàng" unless items.size.between?(1, 50)
          total = items.sum(BigDecimal("0")) { |item| item[:line_total] }
          raise Invalid, "Tổng dự kiến vượt giới hạn 18 chữ số" if total > MAX_TOTAL
          { title: title, purpose: purpose, needed_on: needed_on, estimated_total: total, items: items }
        rescue Date::Error
          raise Invalid, "Ngày cần hàng không hợp lệ"
        end
        def self.rows(value)
          value = value.values if value.is_a?(Hash) && value.keys.all? { |key| /\A\d{1,4}\z/.match?(key.to_s) }
          raise Invalid, "Danh sách dòng hàng không hợp lệ" unless value.is_a?(Array) && value.length <= 50 && value.all?(Hash)
          value.map { |row| row.stringify_keys.slice("description", "quantity", "unit", "estimated_unit_price") }
        end
        def self.text(value, label, limit)
          raise Invalid, "#{label} bắt buộc, tối đa #{limit} ký tự" unless value.is_a?(String) && value.valid_encoding? && value.strip.present? && value.length <= limit
          value.strip
        end
        def self.decimal(value, pattern, message)
          value = value.to_s if value.is_a?(Integer)
          raise Invalid, message unless value.is_a?(String) && pattern.match?(value)
          BigDecimal(value)
        end
      end
    end
  end
end
