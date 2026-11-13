require "digest"
module HrmProcurement
  module Domain
    module Services
      class ReturnContent
        def self.read(attributes)
          raise RequestContent::Invalid, "Dữ liệu trả hàng không hợp lệ" unless attributes.is_a?(Hash)
          key = attributes[:idempotency_key]
          raise RequestContent::Invalid, "Khóa thao tác không hợp lệ" unless key.is_a?(String) && key.valid_encoding? && /\A[a-zA-Z0-9-]{16,64}\z/.match?(key)
          reason = RequestContent.text(attributes[:reason], "Lý do trả", 2000)
          raw = attributes[:items]
          raw = raw.values if raw.is_a?(Hash) && raw.keys.all? { |k| k.to_s.valid_encoding? && /\A\d{1,4}\z/.match?(k.to_s) }
          raise RequestContent::Invalid, "Cần từ 1 đến 50 dòng trả" unless raw.is_a?(Array) && raw.size.between?(1, 50) && raw.all?(Hash)
          seen = []
          items = raw.filter_map do |item|
            row = item.stringify_keys
            id = RequestFilters.id(row["stock_movement_id"]).to_i
            raise RequestContent::Invalid, "Dòng nhập bị lặp" if seen.include?(id)
            seen << id
            next if row["quantity"].nil? || row["quantity"] == ""
            value = row["quantity"]
            unless value.is_a?(Integer) || (value.is_a?(String) && value.valid_encoding? && value.bytesize <= 10)
              raise RequestContent::Invalid, "Số lượng trả không hợp lệ"
            end
            quantity = RequestContent.decimal(row["quantity"], /\A(?:0|[1-9]\d{0,5})(?:\.\d{1,3})?\z/, "Số lượng trả phải dương, tối đa 3 số lẻ")
            raise RequestContent::Invalid, "Số lượng trả phải lớn hơn 0" unless quantity.positive?
            { stock_movement_id: id, quantity: quantity }
          end
          raise RequestContent::Invalid, "Phải trả ít nhất một dòng" if items.empty?
          { idempotency_key: key, reason: reason, items: items.sort_by { |row| row[:stock_movement_id] }, supplied_ids: seen }
        end
        def self.digest(source_id, content)
          Digest::SHA256.hexdigest(JSON.generate([ source_id, content[:reason], content[:items].map { |row| [ row[:stock_movement_id], row[:quantity].to_s("F") ] } ]))
        end
      end
    end
  end
end
