require "digest"
module HrmProcurement
  module Domain
    module Services
      class ReceiptContent
        def self.read(attributes)
          key = attributes[:idempotency_key]
          raise RequestContent::Invalid, "Khóa thao tác không hợp lệ" unless key.is_a?(String) && /\A[a-zA-Z0-9-]{16,64}\z/.match?(key)
          raw = attributes[:items]
          raw = raw.values if raw.is_a?(Hash) && raw.keys.all? { |k| /\A\d{1,4}\z/.match?(k.to_s) }
          raise RequestContent::Invalid, "Cần từ 1 đến 50 dòng nhận" unless raw.is_a?(Array) && raw.size.between?(1, 50) && raw.all?(Hash)
          seen = []
          items = raw.filter_map do |item|
            row = item.stringify_keys
            id = RequestFilters.id(row["purchase_order_line_id"]).to_i
            raise RequestContent::Invalid, "Dòng nhận bị trùng" if seen.include?(id)
            seen << id
            next if row["quantity"].blank? || row["quantity"] == "0"
            qty = RequestContent.decimal(row["quantity"], /\A(?:0|[1-9]\d{0,5})(?:\.\d{1,3})?\z/, "Số lượng nhận phải dương, tối đa 3 số lẻ")
            raise RequestContent::Invalid, "Số lượng nhận phải lớn hơn 0" unless qty.positive?
            { purchase_order_line_id: id, quantity: qty }
          end
          raise RequestContent::Invalid, "Phải nhận ít nhất một dòng" if items.empty?
          reference = attributes[:delivery_reference]
          reference = reference.blank? ? nil : RequestContent.text(reference, "Mã chứng từ giao hàng", 200)
          { idempotency_key: key, received_on: OrderContent.date(attributes[:received_on]), delivery_reference: reference, items: items.sort_by { |item| item[:purchase_order_line_id] }, supplied_ids: seen }
        end
        def self.digest(order_id, content)
          Digest::SHA256.hexdigest(JSON.generate([ order_id, content[:received_on].iso8601, content[:delivery_reference], content[:items].map { |row| [ row[:purchase_order_line_id], row[:quantity].to_s("F") ] } ]))
        end
      end
    end
  end
end
